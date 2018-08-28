//
//  GameScene.swift
//  HoppyBunny
//
//  Created by selman birinci on 8/25/18.
//  Copyright © 2018 selman birinci. All rights reserved.
//

import SpriteKit

enum GameSceneState {
    case active, gameOver
}

class GameScene: SKScene, SKPhysicsContactDelegate{
    
    //game management
    var gameState: GameSceneState = .active
    
    //UI Connections
    var buttonRestart: MSButtonNode!
    
    var hero: SKSpriteNode!
    var scrollLayer: SKNode!
    var obstacleSource: SKNode!
    var obstacleLayer: SKNode!
    var scoreLabel: SKLabelNode!
    
    var sinceTouch: CFTimeInterval = 0
    var spawnTimer: CFTimeInterval = 0
    let fixedDelta: CFTimeInterval = 1.0 / 60.0 /* 60 FSP */
    let scrollSpeed: CGFloat = 100
    
    var points = 0
    
    override func didMove(to view: SKView) {
        // setup your scene here
        
        //recursive node search for 'hero' (child of referenced node)
        hero = self.childNode(withName: "//hero") as! SKSpriteNode
        
        //set reference to scroll layer node
        scrollLayer = self.childNode(withName: "scrollLayer")
        
        //set reference to obstacle Source node
        obstacleSource = self.childNode(withName: "obstacle")
        
        //set reference to obstacle layer code
        obstacleLayer = self.childNode(withName: "obstacleLayer")
        
        //set physics contact delegate
        physicsWorld.contactDelegate = self
        
        //set UI connections
        buttonRestart = self.childNode(withName: "buttonRestart") as! MSButtonNode
        scoreLabel = self.childNode(withName: "scoreLabel") as! SKLabelNode
        
        //setup restart button selection handler
        buttonRestart.selectedHandler = {
            
            //grab reference to our SpriteKit view
            let skView = self.view as SKView?
            
            //load game scene
            let scene = GameScene(fileNamed: "GameScene") as GameScene?
            
            //ensure correct aspect mode
            scene?.scaleMode = .aspectFill
            
            //restart game scene
            skView?.presentScene(scene)
        }
        
        buttonRestart.state = .MSButtonNodeStateHidden
        
        //reset score label
        scoreLabel.text = "\(points)"
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //called when a touch begins
        
        //disable touch if game state is not active
        if gameState != .active {
            return
        }
        
        //reset velocity, helps improve response against cumulative falling velocity
        hero.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        
        //apply vertical impulse
        hero.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 300))
        
        //apply subtle rotation
        hero.physicsBody?.applyAngularImpulse(1)
        
        //reset touch timer
        sinceTouch = 0
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        //called before each frame is rendered
        
        //skip game update if game no longer active
        if gameState != .active {
            return
        }
        
        // grab current velocity
        let velocityY = hero.physicsBody?.velocity.dy ?? 0
        
        // check and cap vertical velocity
        if velocityY > 400 {
            hero.physicsBody?.velocity.dy = 400
        }
        
        //apply falling rotation
        if sinceTouch > 0.2 {
            let impulse = -20000 * fixedDelta
            hero.physicsBody?.applyAngularImpulse(CGFloat(impulse))
        }
        
        //clamp rotation
        hero.zRotation.clamp(v1: CGFloat(-90).degreesToRadians(), CGFloat(30).degreesToRadians())
        hero.physicsBody?.angularVelocity.clamp(v1: -1, 3)
        
        //update last touch timer
        sinceTouch += fixedDelta
        
        //process vorld scrolling
        scrollWorld()
        
        //process obstacles
        updateObstacles()
        
        spawnTimer+=fixedDelta
    }
    
    func scrollWorld() {
        //scroll world
        scrollLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        //loop through scroll layer nodes
        for ground in scrollLayer.children as! [SKSpriteNode] {
            
            //get ground node position, convert node position to scene space
            let groundPosition = scrollLayer.convert(ground.position, to: self)
            
            //check if ground sprite has left the scene
            if groundPosition.x <= -ground.size.width / 2 {
                
                //reposition ground sprite to the second starting position
                let newPosition = CGPoint(x: (self.size.width / 2) + ground.size.width, y: groundPosition.y)
                
                ground.position = self.convert(newPosition, to: scrollLayer)
            }
            
        }
    }
    
    func updateObstacles() {
        //update obtacles
        
        obstacleLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        //loop through obstacle layer nodes
        for obstacle in obstacleLayer.children as! [SKReferenceNode] {
            
            //get obstacle node position, convert node position to scene space
            let obstaclePosition = obstacleLayer.convert(obstacle.position, to: self)
            
            //check if obstacle has left the scene
            if obstaclePosition.x <= -26 {
                //26 is one half the width of an obstacle
                
                //remove obstacle node from obstacle layer
                obstacle.removeFromParent()
            }
        }
        
        //time to add a new obtacle
        if spawnTimer >= 1.5 {
            
            //create a new obstacle by copying the source obstacle
            let newObstacle = obstacleSource.copy() as! SKNode
            obstacleLayer.addChild(newObstacle)
            
            //generate new obstacle position, start just outside screen and with a random y value
            let randomPosition = CGPoint(x: 352, y: CGFloat.random(min: 234, max: 383))
            
            //convert new node position bact to obstacle layer space
            newObstacle.position = self.convert(randomPosition, to: obstacleLayer)
            
            //reset spawn timer
            spawnTimer = 0
        }
        
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        //hero touches anything, gameover
        
        //get references to bodies involved in collision
        let contactA = contact.bodyA
        let contactB = contact.bodyB
        
        //get references to the physics body parent nodes
        let nodeA = contactA.node!
        let nodeB = contactB.node!
        
        //did our hero pass through the goal?
        if nodeA.name == "goal" || nodeB.name == "goal" {
            
            //increment points
            points += 1
            
            //update score label
            scoreLabel.text = String(points)
            
            //we can return now
            return
        }
        
        
        
        //Ensure only called while game running
        if gameState != .active {
            return
        }
        
        //change game state to gameover
        gameState = .gameOver
        
        //stop any new angular velocity being applied
        hero.physicsBody?.allowsRotation = false
        
        //reset angular velocity
        hero.physicsBody?.angularVelocity = 0
        
        //stop hero flapping animation
        hero.removeAllActions()
        
        //create our hero death action
        let heroDeath = SKAction.run ({
            //put out hero face down in the dirt
            self.hero.zRotation = CGFloat(-90).degreesToRadians()
        })
        
        //run action
        hero.run(heroDeath)
        
        //load the shake action resource
        let shakeScene:SKAction = SKAction.init(named: "Shake")!
        
        //loop through all nodes
        for node in self.children {
            //apply effect each ground node
            node.run(shakeScene)
        }
        
        //show restart button
        buttonRestart.state = .MSButtonNodeStateActive
    }
}
