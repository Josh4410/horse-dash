import SpriteKit
import UIKit

protocol GameSceneDelegate: AnyObject {
    func sceneDidUpdate(meters: Int, hay: Int)
    func sceneDidEnterBiome(_ biome: Biome)
    func sceneDidCrash()
}

/// Pseudo-3D three-lane runner. Gameplay state lives in `PlayerModel` and
/// `Spawner`; this class renders it and turns touches into actions.
final class GameScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?

    private final class Entity {
        let node: SKSpriteNode
        let laneX: CGFloat
        let worldZ: CGFloat
        let height: CGFloat
        let kind: ObstacleKind?

        init(node: SKSpriteNode, laneX: CGFloat, worldZ: CGFloat, height: CGFloat, kind: ObstacleKind?) {
            self.node = node
            self.laneX = laneX
            self.worldZ = worldZ
            self.height = height
            self.kind = kind
        }
    }

    private final class Decor {
        let node = SKSpriteNode()
        var worldZ: CGFloat = 0
        var x: CGFloat = 0
    }

    private let skin: Skin
    private let settings: AppSettings
    private var didSetup = false

    // Layout
    private var proj = Projection()
    private var laneWidth: CGFloat = 120
    private var zNear: CGFloat = -200

    // Nodes
    private let world = SKNode()
    private let skyBase = SKSpriteNode()
    private let skyGlow = SKSpriteNode()
    private let sun = SKSpriteNode()
    private let hills = SKSpriteNode()
    private let ground = SKSpriteNode()
    private let road = SKShapeNode()
    private let kerbL = SKShapeNode()
    private let kerbR = SKShapeNode()
    private var bands: [SKSpriteNode] = []
    private var dashes: [SKSpriteNode] = []
    private var decor: [Decor] = []
    private var entities: [Entity] = []
    private var spritePool: [SKSpriteNode] = []
    private let playerRoot = SKNode()
    private let tiltNode = SKNode()
    private let squashNode = SKNode()
    private let horse = SKSpriteNode()
    private let shadow = SKSpriteNode()

    // Textures
    private var runFrames: [SKTexture] = []
    private var jumpFrame = SKTexture()
    private var obstacleTextures: [Int: [ObstacleKind: SKTexture]] = [:]
    private var decorTextures: [DecorKind: SKTexture] = [:]
    private var hayTexture = SKTexture()
    private var dustTexture = SKTexture()
    private var hillsRound = SKTexture()
    private var hillsPointy = SKTexture()

    // Run state
    private var player = PlayerModel()
    private var spawner: Spawner
    private var distance: CGFloat = 0
    private var runSpeed: CGFloat = Tuning.startSpeed
    private var lastTime: TimeInterval = 0
    private var crashed = false
    private var gameplayPaused = false
    private var invulnerable: CGFloat = 0
    private var camX: CGFloat = 0
    private var clock: CGFloat = 0
    private var frameTimer: CGFloat = 0
    private var frameIndex = 0
    private var hay = 0
    private var lastReportedMeters = -1
    private var lastReportedHay = -1
    private var stage = 0
    private var palette: BiomePalette
    private var paletteFrom: BiomePalette
    private var paletteTo: BiomePalette
    private var paletteT: CGFloat = 1
    private var targetPointyHills = false
    private var touchStarts: [ObjectIdentifier: CGPoint] = [:]

    var currentBiomeName: String { Biomes.all[Biomes.biomeIndex(forStage: stage)].name }

    init(size: CGSize, skin: Skin, settings: AppSettings, assistSeconds: CGFloat) {
        self.skin = skin
        self.settings = settings
        var spawner = Spawner(seed: UInt64.random(in: 1...UInt64.max))
        spawner.assistSeconds = assistSeconds
        self.spawner = spawner
        let p = Biomes.all[0].palette
        palette = p
        paletteFrom = p
        paletteTo = p
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0)
        backgroundColor = p.skyTop.ui
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !didSetup else { return }
        didSetup = true
        layout()
        buildTextures()
        buildWorld()
        applyPalette(palette)
        spawnAhead()
        render(dt: 0)
    }

    func setGameplayPaused(_ paused: Bool) {
        gameplayPaused = paused
        lastTime = 0
        touchStarts.removeAll()
    }

    /// Clears nearby obstacles and gives a short grace period. Called once per run.
    func revive() {
        entities.removeAll { e in
            guard e.kind != nil, e.worldZ - distance < Tuning.reviveClearDistance else { return false }
            recycle(e.node)
            return true
        }
        player = PlayerModel(lane: player.lane)
        squashNode.removeAllActions()
        squashNode.setScale(1)
        tiltNode.removeAllActions()
        tiltNode.zRotation = 0
        tiltNode.position = .zero
        invulnerable = Tuning.reviveInvulnerability
        let blink = SKAction.sequence([.fadeAlpha(to: 0.3, duration: 0.1), .fadeAlpha(to: 1, duration: 0.1)])
        horse.run(.repeat(blink, count: Int(Tuning.reviveInvulnerability / 0.2)), withKey: "blink")
        crashed = false
        lastTime = 0
        touchStarts.removeAll()
        Haptics.shared.revive()
    }

    // MARK: Setup

    private func layout() {
        proj.horizonY = size.height * 0.6
        proj.groundY = size.height * 0.16
        laneWidth = min(size.width * 0.3, 170)
        let sBottom = proj.horizonY / (proj.horizonY - proj.groundY)
        zNear = Tuning.cameraDepth * (1 / (sBottom * 1.08) - 1)
    }

    private func buildTextures() {
        for (i, b) in Biomes.all.enumerated() {
            var dict: [ObstacleKind: SKTexture] = [:]
            for kind in ObstacleKind.allCases {
                let img = Art.obstacle(kind, size: Art.obstacleSize(kind, laneWidth: laneWidth),
                                       main: b.obstacleMain.ui, accent: b.obstacleAccent.ui)
                dict[kind] = SKTexture(image: img)
            }
            obstacleTextures[i] = dict
        }
        for kind in DecorKind.allCases {
            decorTextures[kind] = SKTexture(image: Art.decor(kind))
        }
        runFrames = (0..<4).map { SKTexture(image: Art.horse(skin, pose: .run($0))) }
        jumpFrame = SKTexture(image: Art.horse(skin, pose: .jump))
        hayTexture = SKTexture(image: Art.hayBale(diameter: Tuning.hayDiameter * 1.5))
        dustTexture = SKTexture(image: Art.softDot(diameter: 32))
        hillsRound = SKTexture(image: Art.hills(pointy: false))
        hillsPointy = SKTexture(image: Art.hills(pointy: true))
    }

    private func buildWorld() {
        addChild(world)
        let skySize = CGSize(width: size.width, height: size.height - proj.horizonY + 4)

        skyBase.size = skySize
        skyBase.anchorPoint = CGPoint(x: 0.5, y: 0)
        skyBase.position = CGPoint(x: 0, y: proj.horizonY - 2)
        skyBase.zPosition = -100
        world.addChild(skyBase)

        skyGlow.texture = SKTexture(image: Art.verticalFade())
        skyGlow.size = skySize
        skyGlow.anchorPoint = CGPoint(x: 0.5, y: 0)
        skyGlow.position = skyBase.position
        skyGlow.colorBlendFactor = 1
        skyGlow.zPosition = -99
        world.addChild(skyGlow)

        let sunSize = size.width * 0.36
        sun.texture = SKTexture(image: Art.glowDisc())
        sun.size = CGSize(width: sunSize, height: sunSize)
        sun.position = CGPoint(x: size.width * 0.22, y: proj.horizonY + (size.height - proj.horizonY) * 0.5)
        sun.colorBlendFactor = 1
        sun.zPosition = -98
        world.addChild(sun)

        hills.texture = hillsRound
        hills.size = CGSize(width: size.width * 1.6, height: size.height * 0.1)
        hills.anchorPoint = CGPoint(x: 0.5, y: 0)
        hills.position = CGPoint(x: 0, y: proj.horizonY - 1)
        hills.colorBlendFactor = 1
        hills.zPosition = -97
        world.addChild(hills)

        ground.size = CGSize(width: size.width, height: proj.horizonY)
        ground.anchorPoint = CGPoint(x: 0.5, y: 0)
        ground.position = .zero
        ground.zPosition = -90
        world.addChild(ground)

        let bandCount = Int((Tuning.spawnAhead - zNear) / Tuning.bandSpacing) + 2
        for _ in 0..<bandCount {
            let b = SKSpriteNode(color: .white, size: .zero)
            b.anchorPoint = CGPoint(x: 0.5, y: 0)
            b.zPosition = -89
            world.addChild(b)
            bands.append(b)
        }

        for (node, z) in [(road, CGFloat(-80)), (kerbL, -79), (kerbR, -79)] {
            node.lineWidth = 0
            node.strokeColor = .clear
            node.isAntialiased = true
            node.zPosition = z
            world.addChild(node)
        }

        let dashesPerLine = Int((Tuning.spawnAhead - zNear) / Tuning.dashSpacing) + 2
        for _ in 0..<(dashesPerLine * 2) {
            let d = SKSpriteNode(color: .white, size: .zero)
            d.zPosition = -70
            world.addChild(d)
            dashes.append(d)
        }

        let decorCount = 28
        for i in 0..<decorCount {
            let d = Decor()
            d.node.anchorPoint = CGPoint(x: 0.5, y: 0)
            world.addChild(d.node)
            let z = zNear + CGFloat(i) * (Tuning.spawnAhead - zNear) / CGFloat(decorCount)
            placeDecor(d, worldZ: z + CGFloat.random(in: 0...120), side: i % 2 == 0 ? -1 : 1)
            decor.append(d)
        }

        shadow.texture = SKTexture(image: Art.softDot(diameter: 64, alpha: 0.9))
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.size = CGSize(width: laneWidth * 0.75, height: laneWidth * 0.22)
        shadow.zPosition = 999
        world.addChild(shadow)

        let horseWidth = laneWidth * 0.8
        horse.texture = runFrames.first
        horse.size = CGSize(width: horseWidth, height: horseWidth * Art.horseCanvas.height / Art.horseCanvas.width)
        horse.anchorPoint = CGPoint(x: 0.5, y: 0)
        playerRoot.zPosition = 1000
        world.addChild(playerRoot)
        playerRoot.addChild(tiltNode)
        tiltNode.addChild(squashNode)
        squashNode.addChild(horse)
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = lastTime == 0 ? 0 : CGFloat(min(currentTime - lastTime, 1.0 / 30.0))
        lastTime = currentTime
        guard didSetup, !gameplayPaused, !crashed else { return }

        clock += dt
        let meters = Double(distance / Tuning.unitsPerMeter)
        runSpeed = Tuning.speed(atMeters: meters)
        let previousDistance = distance
        distance += runSpeed * dt
        if invulnerable > 0 { invulnerable -= dt }

        for event in player.step(dt) { handle(event) }

        spawnAhead()
        updateEntities(previousDistance: previousDistance)
        updateBiome(meters: meters)
        updatePalette(dt)
        render(dt: dt)
        report()
    }

    private func render(dt: CGFloat) {
        let targetCam = player.x * laneWidth * 0.55
        camX += (targetCam - camX) * min(1, dt * 12)
        updateScenery()
        updatePlayerNode(dt)
    }

    private func report() {
        let m = Int(distance / Tuning.unitsPerMeter)
        guard m != lastReportedMeters || hay != lastReportedHay else { return }
        lastReportedMeters = m
        lastReportedHay = hay
        gameDelegate?.sceneDidUpdate(meters: m, hay: hay)
    }

    // MARK: Spawning

    private func spawnAhead() {
        let batch = spawner.generate(upTo: distance + Tuning.spawnAhead)
        for o in batch.obstacles {
            let biome = Biomes.index(atMeters: Double(o.z / Tuning.unitsPerMeter))
            let node = takeSprite()
            node.texture = obstacleTextures[biome]?[o.kind]
            node.size = Art.obstacleSize(o.kind, laneWidth: laneWidth)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            entities.append(Entity(node: node, laneX: PlayerModel.laneX(o.lane), worldZ: o.z, height: 0, kind: o.kind))
        }
        for h in batch.hay {
            let node = takeSprite()
            node.texture = hayTexture
            node.size = CGSize(width: Tuning.hayDiameter, height: Tuning.hayDiameter)
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            entities.append(Entity(node: node, laneX: PlayerModel.laneX(h.lane), worldZ: h.z, height: h.height, kind: nil))
        }
    }

    private func takeSprite() -> SKSpriteNode {
        let node = spritePool.popLast() ?? SKSpriteNode()
        node.removeAllActions()
        node.alpha = 0
        node.setScale(1)
        node.zRotation = 0
        node.colorBlendFactor = 0
        if node.parent == nil { world.addChild(node) }
        return node
    }

    private func recycle(_ node: SKSpriteNode) {
        node.removeAllActions()
        node.removeFromParent()
        spritePool.append(node)
    }

    // MARK: Entities and collisions

    private func updateEntities(previousDistance: CGFloat) {
        var i = 0
        while i < entities.count {
            let e = entities[i]
            let relZ = e.worldZ - distance
            if relZ < zNear - 60 {
                recycle(e.node)
                entities.remove(at: i)
                continue
            }
            let s = proj.scale(relZ)
            if let kind = e.kind {
                e.node.position = proj.point(e.laneX * laneWidth - camX, 0, relZ)
                e.node.setScale(s)
                if !crashed, invulnerable <= 0,
                   hits(kind, laneX: e.laneX, relZ: relZ, previousRelZ: e.worldZ - previousDistance) {
                    crash()
                }
            } else {
                let bob = sin(clock * 5 + e.worldZ * 0.01) * 6
                e.node.position = proj.point(e.laneX * laneWidth - camX, e.height + bob, relZ)
                e.node.setScale(s)
                e.node.xScale = s * (0.45 + 0.55 * abs(cos(clock * 3 + e.worldZ * 0.003)))
                if relZ < 50, relZ > -60, abs(player.x - e.laneX) < 0.5, abs(player.y + 40 - e.height) < 105 {
                    collect(e)
                    entities.remove(at: i)
                    continue
                }
            }
            e.node.zPosition = 1000 - relZ * 0.1
            e.node.alpha = fogAlpha(relZ)
            i += 1
        }
    }

    /// Swept test: did the obstacle cross the player's depth this frame?
    private func hits(_ kind: ObstacleKind, laneX: CGFloat, relZ: CGFloat, previousRelZ: CGFloat) -> Bool {
        guard relZ < 30, previousRelZ > -70, abs(player.x - laneX) < 0.42 else { return false }
        switch kind {
        case .hurdle: return player.y < Tuning.hurdleClearY
        case .overhead: return !(player.isSliding && !player.isAirborne)
        case .block: return true
        }
    }

    private func collect(_ e: Entity) {
        hay += 1
        Haptics.shared.hay()
        let node = e.node
        let pop = SKAction.group([
            .scale(by: 1.7, duration: 0.12),
            .fadeOut(withDuration: 0.12),
            .moveBy(x: 0, y: 34, duration: 0.12),
        ])
        node.run(.sequence([pop, .run { [weak self, weak node] in
            guard let self, let node else { return }
            self.recycle(node)
        }]))
    }

    private func fogAlpha(_ relZ: CGFloat) -> CGFloat {
        min(1, max(0, (Tuning.spawnAhead - relZ) / 1600))
    }

    // MARK: Scenery

    private func quad(_ x0: CGFloat, _ x1: CGFloat) -> CGPath {
        let zf = Tuning.spawnAhead
        return Art.poly([
            proj.point(x0 - camX, 0, zNear), proj.point(x1 - camX, 0, zNear),
            proj.point(x1 - camX, 0, zf), proj.point(x0 - camX, 0, zf),
        ])
    }

    private func updateScenery() {
        let half = laneWidth * 1.5
        let kerb: CGFloat = 22
        road.path = quad(-half, half)
        kerbL.path = quad(-half - kerb, -half)
        kerbR.path = quad(half, half + kerb)
        hills.position.x = -camX * 0.08

        // Crop-row bands across the ground sell the speed.
        let bandStart = floor((distance + zNear) / Tuning.bandSpacing) * Tuning.bandSpacing
        for (i, band) in bands.enumerated() {
            let rz = bandStart + CGFloat(i) * Tuning.bandSpacing - distance
            let rzEnd = rz + Tuning.bandSpacing * 0.5
            guard rzEnd > zNear else { band.isHidden = true; continue }
            band.isHidden = false
            let y0 = proj.point(0, 0, max(rz, zNear)).y
            let y1 = proj.point(0, 0, rzEnd).y
            band.position = CGPoint(x: 0, y: y0)
            band.size = CGSize(width: size.width, height: max(0, y1 - y0))
        }

        // Lane dashes.
        let dashStart = floor((distance + zNear) / Tuning.dashSpacing) * Tuning.dashSpacing
        let perLine = dashes.count / 2
        for (i, dash) in dashes.enumerated() {
            let lineX: CGFloat = (i < perLine ? -0.5 : 0.5) * laneWidth - camX
            let rz = dashStart + CGFloat(i % perLine) * Tuning.dashSpacing - distance
            let rzEnd = rz + Tuning.dashLength
            guard rzEnd > zNear else { dash.isHidden = true; continue }
            dash.isHidden = false
            let a = proj.point(lineX, 0, max(rz, zNear))
            let b = proj.point(lineX, 0, rzEnd)
            let dx = b.x - a.x, dy = b.y - a.y
            dash.position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            dash.size = CGSize(width: 7 * proj.scale(max(rz, zNear)), height: hypot(dx, dy))
            dash.zRotation = -atan2(dx, dy)
            dash.alpha = fogAlpha(rz)
        }

        for d in decor {
            var rz = d.worldZ - distance
            if rz < zNear - 120 {
                placeDecor(d, worldZ: distance + Tuning.spawnAhead + CGFloat.random(in: 0...200),
                           side: Bool.random() ? -1 : 1)
                rz = d.worldZ - distance
            }
            d.node.position = proj.point(d.x - camX, 0, rz)
            d.node.setScale(proj.scale(rz))
            d.node.zPosition = 1000 - rz * 0.1
            d.node.alpha = fogAlpha(rz)
        }
    }

    private func placeDecor(_ d: Decor, worldZ: CGFloat, side: CGFloat) {
        d.worldZ = worldZ
        let biome = Biomes.biome(atMeters: Double(worldZ / Tuning.unitsPerMeter))
        let kind = biome.decor.randomElement() ?? .tree
        let size = Art.decorSize(kind)
        d.node.texture = decorTextures[kind]
        d.node.size = size
        d.x = side * (laneWidth * 1.5 + 40 + size.width / 2 + CGFloat.random(in: 0...420))
    }

    // MARK: Player rendering and feedback

    private func updatePlayerNode(_ dt: CGFloat) {
        let x = player.x * laneWidth - camX
        playerRoot.position = proj.point(x, player.y, 0)
        shadow.position = proj.point(x, 0, 0)
        let h = min(1, player.y / Tuning.jumpHeight)
        shadow.setScale(1 - 0.45 * h)
        shadow.alpha = 0.35 * (1 - 0.6 * h)

        if player.isAirborne {
            horse.texture = jumpFrame
        } else {
            frameTimer += dt
            let frameDuration = 0.075 * Tuning.startSpeed / runSpeed
            if frameTimer >= frameDuration {
                frameTimer = 0
                frameIndex = (frameIndex + 1) % runFrames.count
            }
            horse.texture = runFrames[frameIndex]
        }
    }

    private func handle(_ event: PlayerEvent) {
        switch event {
        case .laneChanged(let dir):
            Haptics.shared.laneChange()
            tilt(dir)
        case .laneBlocked(let dir):
            Haptics.shared.laneBlocked()
            nudge(dir)
        case .jumped:
            Haptics.shared.jump()
            squash(x: 0.88, y: 1.14, hold: 0.06, back: 0.16)
        case .landed:
            Haptics.shared.land()
            squash(x: 1.16, y: 0.84, hold: 0.05, back: 0.14)
            dust()
        case .slideStarted:
            Haptics.shared.slide()
            squashNode.removeAction(forKey: "squash")
            squashNode.run(.group([.scaleX(to: 1.15, duration: 0.06), .scaleY(to: 0.55, duration: 0.06)]), withKey: "squash")
            dust()
        case .slideEnded:
            let back = SKAction.scale(to: 1, duration: 0.1)
            back.timingMode = .easeOut
            squashNode.run(back, withKey: "squash")
        case .fastFall:
            Haptics.shared.fastFall()
        }
    }

    private func tilt(_ dir: Int) {
        tiltNode.removeAction(forKey: "tilt")
        let lean = SKAction.rotate(toAngle: CGFloat(-dir) * 0.16, duration: 0.05)
        lean.timingMode = .easeOut
        let settle = SKAction.rotate(toAngle: 0, duration: 0.14)
        settle.timingMode = .easeInEaseOut
        tiltNode.run(.sequence([lean, settle]), withKey: "tilt")
    }

    private func nudge(_ dir: Int) {
        tiltNode.removeAction(forKey: "nudge")
        tiltNode.position = .zero
        let d = CGFloat(dir) * 12
        tiltNode.run(.sequence([.moveBy(x: d, y: 0, duration: 0.04), .moveBy(x: -d, y: 0, duration: 0.1)]), withKey: "nudge")
    }

    private func squash(x: CGFloat, y: CGFloat, hold: TimeInterval, back: TimeInterval) {
        squashNode.removeAction(forKey: "squash")
        let squeeze = SKAction.group([.scaleX(to: x, duration: hold), .scaleY(to: y, duration: hold)])
        let restore = SKAction.scale(to: 1, duration: back)
        restore.timingMode = .easeOut
        squashNode.run(.sequence([squeeze, restore]), withKey: "squash")
    }

    private func dust() {
        let origin = shadow.position
        let tint = palette.ground.shade(1.3).ui
        for i in 0..<6 {
            let puff = SKSpriteNode(texture: dustTexture)
            puff.color = tint
            puff.colorBlendFactor = 1
            puff.size = CGSize(width: 22, height: 22)
            puff.position = origin
            puff.zPosition = 1001
            world.addChild(puff)
            let dir: CGFloat = i % 2 == 0 ? -1 : 1
            let move = SKAction.moveBy(x: dir * CGFloat.random(in: 20...50), y: CGFloat.random(in: 4...22), duration: 0.3)
            move.timingMode = .easeOut
            puff.run(.sequence([.group([move, .scale(to: 1.8, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        }
    }

    private func crash() {
        crashed = true
        touchStarts.removeAll()
        Haptics.shared.crash()
        if !settings.reduceCameraShake { shake() }
        horse.run(.sequence([
            .colorize(with: .red, colorBlendFactor: 0.65, duration: 0.04),
            .colorize(withColorBlendFactor: 0, duration: 0.3),
        ]), withKey: "flash")
        squash(x: 1.22, y: 0.78, hold: 0.05, back: 0.25)
        run(.sequence([
            .wait(forDuration: 0.55),
            .run { [weak self] in self?.gameDelegate?.sceneDidCrash() },
        ]), withKey: "crashDelay")
    }

    private func shake() {
        world.removeAction(forKey: "shake")
        var steps: [SKAction] = []
        var amp: CGFloat = 16
        for _ in 0..<6 {
            let offset = CGPoint(x: CGFloat.random(in: -amp...amp), y: CGFloat.random(in: -amp...amp))
            steps.append(.move(to: offset, duration: 0.03))
            amp *= 0.7
        }
        steps.append(.move(to: .zero, duration: 0.04))
        world.run(.sequence(steps), withKey: "shake")
    }

    // MARK: Biomes

    private func updateBiome(meters: Double) {
        let s = Biomes.stage(atMeters: meters)
        guard s != stage else { return }
        stage = s
        let biome = Biomes.all[Biomes.biomeIndex(forStage: s)]
        paletteFrom = palette
        paletteTo = biome.palette
        paletteT = 0
        targetPointyHills = biome.pointyHills
        Haptics.shared.biomeChange()
        gameDelegate?.sceneDidEnterBiome(biome)
    }

    private func updatePalette(_ dt: CGFloat) {
        guard paletteT < 1 else { return }
        paletteT = min(1, paletteT + dt / 1.4)
        let t = paletteT * paletteT * (3 - 2 * paletteT)
        palette = paletteFrom.mix(paletteTo, t)
        applyPalette(palette)
        if paletteT >= 0.5 {
            hills.texture = targetPointyHills ? hillsPointy : hillsRound
        }
    }

    private func applyPalette(_ p: BiomePalette) {
        backgroundColor = p.skyTop.ui
        skyBase.color = p.skyTop.ui
        skyGlow.color = p.skyBottom.ui
        sun.color = p.sun.ui
        hills.color = p.hills.ui
        ground.color = p.ground.ui
        let bandColor = p.ground.shade(0.9).ui
        bands.forEach { $0.color = bandColor }
        road.fillColor = p.road.ui
        kerbL.fillColor = p.kerb.ui
        kerbR.fillColor = p.kerb.ui
        let line = p.laneLine.ui
        dashes.forEach { $0.color = line }
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            touchStarts[ObjectIdentifier(t)] = t.location(in: self)
        }
    }

    /// Fires as soon as the finger passes the threshold, without waiting for
    /// the touch to end. One action per swipe.
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let id = ObjectIdentifier(t)
            guard let start = touchStarts[id] else { continue }
            let p = t.location(in: self)
            let dx = p.x - start.x
            let dy = p.y - start.y
            guard max(abs(dx), abs(dy)) >= Tuning.swipeThreshold else { continue }
            touchStarts[id] = nil
            let action: PlayerAction
            if abs(dx) > abs(dy) {
                action = dx > 0 ? .right : .left
            } else {
                action = dy > 0 ? .jump : .slide
            }
            input(action)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchStarts[ObjectIdentifier(t)] = nil }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchStarts[ObjectIdentifier(t)] = nil }
    }

    func input(_ action: PlayerAction) {
        guard didSetup, !crashed, !gameplayPaused else { return }
        for event in player.perform(action) { handle(event) }
    }
}
