//
//  ViewController.swift
//  Nasty Pumpkins
//
//  Created by Aditya Gupta on 6/10/19.
//  Copyright © 2019 Aditya Gupta. All rights reserved.
//

import UIKit
import ARKit
import AVFoundation
import AudioToolbox

enum BitMaskCategory: Int {
    case rock = 2
    case target = 5
    case plane = 0
}

class ViewController: UIViewController, SCNPhysicsContactDelegate {
    
    //Max and current sones/objects
    var currentStones: Float = 0.0
    var maxStones: Float = 15.0
    
    var audioPlayer = AVAudioPlayer()
    
//    var centroidList: [SCNVector3] = []
//    var eulerList: [SCNVector3] = []
//    var boundaryList: [ObjectBoundaries] = []
//    var transform : simd_float4x4 = matrix_identity_float4x4
    //variable to toggle oreientation button
    var buttonIsOn: Bool = false
    var gameison: Bool = false
    @IBOutlet weak var homeButton: UIButton!
    //No. of stones progress bar
    @IBOutlet weak var timeLeft: UIProgressView!

    @IBOutlet weak var target: UIButton!
    @IBOutlet weak var view3d: UIButton!
    @IBOutlet weak var label: UIButton!
    @IBOutlet weak var showAllModelledObjButton: UIButton!
    
    
    @IBOutlet weak var gameOverLabel: UIButton!
    
    //Button press to go back to main page
    @IBOutlet weak var startButtonObject: UIButton!
    @IBOutlet weak var stopButtonObject: UIButton!
    
    @IBOutlet weak var startgame: UIButton!
    // Added for shape optimization
    var objectCount = -1
    var lastEulerAngleDetetedForObject: SCNVector3 = SCNVector3(0,0,0)
    var dist_x: [Float] = []
    var dist_y: [Float] = []
    var dist_z: [Float] = []
    var param_array = Set<vector_float3>()
    var realWorldObjectArray: [[SCNVector3]] = []
    var realWorldObjectCentroidArray: [SCNVector3] = []
    var realWorldObjectEulerArray: [SCNVector3] = []
    var realWorldObjectMaxBoundriesArray: [ObjectBoundaries] = []
    var transformcordinate : simd_float4x4 = matrix_identity_float4x4
    var scanningComplete = true
    var x = Float(0)
    var y = Float(0)
    var z = Float(0)
    var indices: [Int32] = []
    var vertices: [SCNVector3] = []
    ///////////////////////////////////////////////////////////////////
    
    
    
    //Button press to show 3D Orientation and feature points
    @IBAction func orientation(_ sender: Any) {
        if buttonIsOn{
            self.sceneView.debugOptions = []
            buttonIsOn = false
        } else{
            self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
            buttonIsOn = true
        }
    }
    
    @IBAction func gameOverPopup(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    
    //Add sceneView
    @IBOutlet var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    //Variable power to add impulse to stone throws
    var power: Float = 50
    var Target: SCNNode?
    var rock: SCNNode?
    
    
    //Standard function
    override func viewDidLoad() {
       
        super.viewDidLoad()
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        self.sceneView.session.run(configuration)
        self.sceneView.autoenablesDefaultLighting = true

        /////////////// game play is hidden intitally
        timeLeft.isHidden = true
        homeButton.isHidden = true
        view3d.isHidden  = true
        label.isHidden = true
        target.isHidden = true
        gameOverLabel.isHidden = true
        
        
        /////////////////////////////
        //Recognize the phone tap gesture
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(sender:)))
        self.sceneView.addGestureRecognizer(gestureRecognizer)
        self.sceneView.scene.physicsWorld.contactDelegate = self
        
        
        timeLeft.layer.cornerRadius = 2
        timeLeft.clipsToBounds = true
        timeLeft.layer.sublayers![1].cornerRadius = 2
        timeLeft.subviews[1].clipsToBounds = true
        
        // Below rendering is done in startgame button
        //Defining circular progress bar
//        let circularProgress = CircularProgress(frame: CGRect(x: 10.0, y: 30.0, width: 100.0, height: 100.0))
//        circularProgress.progressColor = UIColor.orange
//        //(red: 52.0/255.0, green: 141.0/255.0, blue: 252.0/255.0, alpha: 1.0)
//        circularProgress.trackColor = UIColor.white
//        //(red: 52.0/255.0, green: 141.0/255.0, blue: 252.0/255.0, alpha: 0.6)
//        circularProgress.tag = 101
//        circularProgress.center = self.view.center
//        self.view.addSubview(circularProgress)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL.init(fileURLWithPath: Bundle.main.path(forResource: "ghostly", ofType: "mp3")!))
            audioPlayer.prepareToPlay()
        }
        catch{
            print("Sound File Not Found")
        }
        
    }
    
    
    //Standard
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //After recognizing tap, now adding functionality to it
    @objc func handleTap(sender: UITapGestureRecognizer) {
        if gameison{
        guard let sceneView = sender.view as? ARSCNView else {return}
        guard let pointOfView = sceneView.pointOfView else {return}
        //Standard position of objects intake
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let position = orientation + location
        
        //making a rock to throw at pumpkins
        //rock is a sphere
        let rock = SCNNode(geometry: SCNSphere(radius: 0.2))
        rock.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "rock1")
        //make rock initial starting point as cameras/users loci
        rock.position = position
        //body type is dynamic as rock is to be thrown, unlike pumpinks which are kept static
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: rock, options: nil))
        
        //let rocks take a parabolic throw curve, thus affected by gravity
        body.isAffectedByGravity = true
        rock.physicsBody = body
        rock.physicsBody?.applyForce(SCNVector3(orientation.x*power, orientation.y*power, orientation.z*power), asImpulse: true)
        rock.physicsBody?.categoryBitMask = BitMaskCategory.rock.rawValue
        rock.physicsBody?.contactTestBitMask = BitMaskCategory.target.rawValue
        self.sceneView.scene.rootNode.addChildNode(rock)
        
        
        //Counting stones
        perform(#selector(updateProgress), with: nil, afterDelay: 1.0 )
        }
        else{
            if(self.isScanningComplete()){
                            // TODO: Show a message to tell the user to press the start tapping option
                            return
            }
            let currentPoint = sender.location(in: sceneView)
            // Get all feature points in the current frame
            
            let fp = self.sceneView.session.currentFrame?.rawFeaturePoints
            guard let count = fp?.points.count else{return}
            // Create a material
            let material = createMaterial()
            var point_count = 0
            // Loop over them and check if any exist near our touch location
            // If a point exists in our range, let's draw a sphere at that feature point
            print(count)
            for index in 0..<count {
                let point = SCNVector3.init((fp?.points[index].x)!, (fp?.points[index].y)!, (fp?.points[index].z)!)
                let projection = self.sceneView.projectPoint(point)
                let xRange:ClosedRange<Float> = Float(currentPoint.x)-100.0...Float(currentPoint.x)+100.0
                let yRange:ClosedRange<Float> = Float(currentPoint.y)-100.0...Float(currentPoint.y)+100.0
                if (xRange ~= projection.x && yRange ~= projection.y) {
                    let ballShape = SCNSphere(radius: 0.002)
                    ballShape.materials = [material]
                    let ballnode = SCNNode(geometry: ballShape)
                    ballnode.position = point
                    self.sceneView.scene.rootNode.addChildNode(ballnode)
                    // We'll also save it for later use in our [SCNVector]
                    //                let p_oints = CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
                    //                points.append(p_oints)
                    //                pointcloud.insert(vector_float3(point))
                    x = x + point.x
                    y = y + point.y
                    z = z + point.z
                    point_count+=1
                    
                }
            }
            if point_count>0{
                
                print("x",(((x/Float(point_count))*100).rounded(.down))/100)
                print("y",y/Float(point_count))
                print("z",z/Float(point_count))
                
                x=(((x/Float(point_count))*100).rounded(.down))/100
                y=(((y/Float(point_count))*100).rounded(.down))/100
                z=(((z/Float(point_count))*100).rounded(.down))/100
                let sphere2 = SCNNode(geometry: SCNSphere(radius: 0.03))
                sphere2.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
                sphere2.position = SCNVector3(CGFloat(x),CGFloat(y),CGFloat(z))
                self.sceneView.scene.rootNode.addChildNode(sphere2)
                vertices.append(SCNVector3([x,y,z]))
                x=0
                y=0
                z=0
                
            }
            
            
            
        }
        
    }
    
    
    
    //Button to make 5 pumpkins at different (or random) distances
    @IBAction func addTargets(_ sender: UIButton) {
        
        sender.isHidden = true
        
//        var n:Int = 0
        // Getting the PLane Information
        //Now proceed to show the object
        var index = 0;
        var x:Float = 0
        var y:Float = 0
        var z:Float = 0
        //var eulerangles : SCNVector3
        //Objects are scanned  scanned now. Lets Store its 3D ARCloud Model
        for _ in self.realWorldObjectArray{
            /// Computed parameters of all the playing sufraces detected
            /// These are the position, width, height and euler angles w.r.t to the plane generated
            //let objectBoundaries = self.realWorldObjectMaxBoundriesArray[index]
//            let height = 2*(self.getHeightBasedOnOrientation(objectBoundaries: objectBoundaries,eulerAngle: self.realWorldObjectEulerArray[index]))
//            let width = 2 * CGFloat(objectBoundaries.getMaxX())
            x = self.realWorldObjectCentroidArray[index].x
            y = self.realWorldObjectCentroidArray[index].y
            z = self.realWorldObjectCentroidArray[index].z
            let sphere3 = SCNNode(geometry: SCNSphere(radius: 0.03))
            sphere3.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            sphere3.position = SCNVector3([x,y,z])
            self.sceneView.scene.rootNode.addChildNode(sphere3)
            //eulerangles = self.realWorldObjectEulerArray[index]
            ///----------------------------------------------------
//            while(n<=5){
//
////                let randX = Float.random(in: x-0.5...x+0.5)
////                let randY = Float.random(in: y-0.5...y+0.5)
////                let randZ = Float.random(in: z+0.5...z+0.8)
//
//                //self.addPumpkin(x: x+Float(n), y: y+Float(n), z: z-5*Float(n))
//                let sphere = SCNNode(geometry: SCNSphere(radius: 0.03))
//                sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.green
//                sphere.position = SCNVector3(x,y,z-0.1*Float(n))
//                self.sceneView.scene.rootNode.addChildNode(sphere)
//
//                n += 1
//            }
            
            self.addPumpkin(x: x, y: y, z: z)
            self.addPumpkin(x: x, y: y, z: z)
            self.addPumpkin(x: x, y: y, z: z)
            
            index += 1
        }
       
        
        //Make placeholder wall
//        var index = 0
//        for _ in self.realWorldObjectCentroidArray{
//            print("in for loop")
//            self.addWall(x: self.realWorldObjectCentroidArray[index].x, y: self.realWorldObjectCentroidArray[index].x, z: self.realWorldObjectCentroidArray[index].x, width: self.realWorldObjectMaxBoundriesArray[index].width, height: realWorldObjectMaxBoundriesArray[index].height, eulerangle: realWorldObjectEulerArray[index])
//            index+=1
//        }
        
        
        //Call horizontal progress bar
        timeLeft.setProgress(currentStones, animated: true)
        //perform(#selector(updateProgress), with: nil, afterDelay: 1.0 )
        
        //Call circular progress bar
        self.perform(#selector(animateProgress), with: nil, afterDelay: 1)
        
    }
    
    
//    func addWall(x: Float, y: Float, z: Float, width: Float, height: Float, eulerangle: SCNVector3) {
//        print("in add wall")
//        let wall = SCNNode(geometry: SCNPlane(width: 2*CGFloat(width), height: 2*CGFloat(height)))
//        wall.geometry?.firstMaterial?.diffuse.contents = UIColor.red
//        wall.position = SCNVector3(x,y,z)
//        wall.eulerAngles = eulerangle
//
//        let wallBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: wall, options: nil))
//        wall.physicsBody = wallBody
//
//        self.sceneView.scene.rootNode.addChildNode(wall)
//
//    }
    
    
    func addPumpkin(x: Float, y: Float, z: Float) {
        //Pumpkin is a 3D scnekit item
        let pumpkinScene = SCNScene(named: "Media.scnassets/Halloween_Pumpkin.scn")
        let pumpkinNode = (pumpkinScene?.rootNode.childNode(withName: "Halloween_Pumpkin", recursively: false))!
        pumpkinNode.position = SCNVector3(x,y,z-Float.random(in: 2...4))
        
        let phy_body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: pumpkinNode, options: nil))
        
        pumpkinNode.physicsBody = phy_body
        pumpkinNode.physicsBody?.categoryBitMask = BitMaskCategory.target.rawValue
        pumpkinNode.physicsBody?.contactTestBitMask = BitMaskCategory.rock.rawValue
        self.sceneView.scene.rootNode.addChildNode(pumpkinNode)
        
        //randomly assigning either 2D movement or movement towards POV
        let number = Int.random(in: 0 ... 1)
        if number == 0 {
            self.twoDimensionalMovement(node: pumpkinNode)
        } else {
            print("Initial Positiom")
            print (pumpkinNode.position)
            self.towardsPOVMovement(node: pumpkinNode)
        }
        
        audioPlayer.play()
    }
    
    func towardsPOVMovement(node: SCNNode) {
        guard let pointOfView1 = self.sceneView.pointOfView else {return}
        let transform1 = pointOfView1.transform
//        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location1 = SCNVector3(transform1.m41, transform1.m42, transform1.m43)
//        let position = orientation + location
        
        let hover = SCNAction.move(to: location1, duration: 3)
        
        print("Towards POV working")
        node.runAction(hover)
        
//        node.runAction(
//            SCNAction.sequence([SCNAction.wait(duration: 3.0),
//                                SCNAction.removeFromParentNode()])
//        )

        // bokeh when pumpkin reaches POV        
        let dispatchQueue = DispatchQueue(label: "QueueIdentification", qos: .background)
        dispatchQueue.async{
            //Time consuming task here
            while (true) {
                if(SCNVector3EqualToVector3(node.position, location1)) {
                    print ("Running")
                    let bokeh2 = SCNParticleSystem(named: "Media.scnassets/bokeh2.scnp", inDirectory: nil)
                    bokeh2?.loops = false
                    bokeh2?.particleLifeSpan = 6
                    bokeh2?.emitterShape = node.geometry
                    let bokeh2Node = SCNNode()
                    bokeh2Node.addParticleSystem(bokeh2!)
                    bokeh2Node.position = location1
                    self.sceneView.scene.rootNode.addChildNode(bokeh2Node)
                    node.runAction(SCNAction.removeFromParentNode())
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    AudioServicesPlaySystemSound (SystemSoundID(1003))
                    
                    let plane_count = self.realWorldObjectCentroidArray.count
                    
                    if (plane_count > 0) {
                        let index_val = Int.random(in: 0 ... plane_count-1)
                        self.addPumpkin(x: self.realWorldObjectCentroidArray[index_val].x, y: self.realWorldObjectCentroidArray[index_val].y, z: self.realWorldObjectCentroidArray[index_val].z)
                    }
                    break
                }
            }
        }

    }
    
    
    func twoDimensionalMovement(node: SCNNode) {
        let hover_x = CGFloat.random(in: -5...5)
        let hover_y = CGFloat.random(in: -5...5)
        let hoverUp = SCNAction.moveBy(x: hover_x, y: hover_y, z: 0, duration: 1)
        let hoverDown = SCNAction.moveBy(x: -(hover_x), y: -(hover_y), z: 0, duration: 1)
        let hoverSequence = SCNAction.sequence([hoverUp, hoverDown])
        let repeatForever = SCNAction.repeatForever(hoverSequence)
        
        node.runAction(repeatForever)
        
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        
        // Nothing should happen if rock or pumpkin touches the plane
        if (nodeA.physicsBody?.categoryBitMask == BitMaskCategory.plane.rawValue || nodeB.physicsBody?.categoryBitMask == BitMaskCategory.plane.rawValue) {
            return
        }
        else {
            if nodeA.physicsBody?.categoryBitMask == BitMaskCategory.target.rawValue {
                self.Target = nodeA
                self.rock = nodeB
            } else if nodeB.physicsBody?.categoryBitMask == BitMaskCategory.target.rawValue {
                self.Target = nodeB
                self.rock = nodeA
            }
            
            //Add animation = bokeh to pumkin being hit, then delte pumpkin child node
            let bokeh = SCNParticleSystem(named: "Media.scnassets/bokeh.scnp", inDirectory: nil)
            bokeh?.loops = false
            bokeh?.particleLifeSpan = 3
            bokeh?.emitterShape = Target?.geometry
            let bokehNode = SCNNode()
            bokehNode.addParticleSystem(bokeh!)
            bokehNode.position = contact.contactPoint
            self.sceneView.scene.rootNode.addChildNode(bokehNode)
            //AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            Target?.removeFromParentNode()
            rock?.removeFromParentNode()
            
            let plane_count = self.realWorldObjectCentroidArray.count
            
            // Add a new pumpkin everytime one gets shot
            if (plane_count > 0) {
                let index_val = Int.random(in: 0 ... plane_count-1)
                self.addPumpkin(x: self.realWorldObjectCentroidArray[index_val].x, y: self.realWorldObjectCentroidArray[index_val].y, z: self.realWorldObjectCentroidArray[index_val].z)
            }
        }
        
    }


    //Function for timer progress bar in the game
    @objc func updateProgress(){
        
        if currentStones < maxStones{
            currentStones = currentStones + 1.0
            timeLeft.progress = currentStones/maxStones
            
        }else{
            /////////////// game play is hidden
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            timeLeft.isHidden = true
            homeButton.isHidden = true
            view3d.isHidden  = true
            label.isHidden = true
            target.isHidden = true
            
            //CircularProgress.removeFromSuperview()

            gameOverLabel.isHidden = false

        }
            
        //currentStones = currentStones + 1.0
        //timeLeft.progress = currentStones/maxStones
        
        /*
        if currentStones < maxStones{
            perform(#selector(updateProgress), with: nil, afterDelay: 1.0 )
        }else{
            currentStones = 0.0
            
            return
        }*/
    }
    
    //Circular Progress bar - call touch class
    @objc func animateProgress() {
        let cp = self.view.viewWithTag(101) as! CircularProgress
        //Define time duration allowed
        cp.setProgressWithAnimation(duration: 15.0, value: 1.0)
    }
    //////////////////?????????????????/////////////////////////
    ///////////////// Code Integration /////////////////////////
    /////////////////////????????????????//////////////////////
    
    @IBAction func startGame(_ sender: Any) {
        showAllModelledObjButton.isHidden = true
        startButtonObject.isHidden = true
        stopButtonObject.isHidden = true
        timeLeft.isHidden = false
        homeButton.isHidden = false
        view3d.isHidden  = false
        label.isHidden = false
        target.isHidden = false
        let circularProgress = CircularProgress(frame: CGRect(x: 10.0, y: 30.0, width: 100.0, height: 100.0))
        circularProgress.progressColor = UIColor.orange
        //(red: 52.0/255.0, green: 141.0/255.0, blue: 252.0/255.0, alpha: 1.0)
        circularProgress.trackColor = UIColor.white
        //(red: 52.0/255.0, green: 141.0/255.0, blue: 252.0/255.0, alpha: 0.6)
        circularProgress.tag = 101
        circularProgress.center = self.view.center
        self.view.addSubview(circularProgress)
        gameison = true
        startgame.isHidden=true
        
    }
    func getDyamicEulerAngles() -> SCNVector3 {
        guard let pointOfView = self.sceneView.pointOfView else {return SCNVector3(0,0,0)}
        let transform = pointOfView.eulerAngles
        return SCNVector3(transform.x, transform.y, transform.z)
    }
    
    func createMaterial() -> SCNMaterial {
        let clearMaterial = SCNMaterial()
        clearMaterial.diffuse.contents = UIColor(red:0.12, green:0.61, blue:1.00, alpha:1.0)
        clearMaterial.locksAmbientWithDiffuse = true
        clearMaterial.transparency = 0.2
        return clearMaterial
    }
    
    func showAllModelledObjects() {
        if(self.isCentroidCalculationRequired()){
            self.calculateCentroidForAllRealWorldObjects()
            print("All Centroids and Boundaries Calculated")
            print(self.realWorldObjectCentroidArray)
        }
        //Now proceed to show the object
        var count = 0;
        //Objects are scanned  scanned now. Lets Store its 3D ARCloud Model
        for _ in self.realWorldObjectArray{
            self.placePlaneInFrontOfObjects(index: count)
            count += 1
        }
    }
    
    
    func placeSphere( point: SCNVector3, width:Float, height: Float ) {
        let spehere = SCNNode(geometry: SCNSphere(radius: 0.05))
        spehere.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        spehere.position = SCNVector3( point.x ,point.y, point.z-0.5)
        self.sceneView.scene.rootNode.addChildNode( spehere )
    }
    
    func isCentroidCalculationRequired() -> Bool {
        if(realWorldObjectArray.count == realWorldObjectCentroidArray.count){
            return false
        }
        return true
    }
    
    func calculateCentroidForAllRealWorldObjects() {
        var count = 0
        for temp_param_array in self.realWorldObjectArray{
            if(count >= realWorldObjectCentroidArray.count ){
                let centroidAndBoundaries = self.calculateCentroidOfPoints(points: temp_param_array)
                
                realWorldObjectCentroidArray.append( centroidAndBoundaries.0)
                
                realWorldObjectMaxBoundriesArray.append(centroidAndBoundaries.1)
                
            }
            count += 1
        }
    }
    
    func calculateCentroidOfPoints(points :[SCNVector3]) -> (SCNVector3, ObjectBoundaries){
        var xSum: Float = 0.0;
        var ySum: Float = 0.0;
        var zSum: Float = 0.0;
        let pointCount = Float(points.count)
        for point in points {
            var vectorFloatPoint = vector_float3( point )
            xSum += vectorFloatPoint.x
            ySum += vectorFloatPoint.y
            zSum += vectorFloatPoint.z
        }
        
        let xC = xSum / pointCount
        let yC = ySum / pointCount
        let zC = zSum / pointCount
        
        for point in points {
            dist_x.append(abs(point.x-xC))
            dist_y.append(abs(point.y-yC))
            dist_z.append(abs(point.z-zC))
        }
        
        dist_x = dist_x.sorted(by: >)
        dist_y = dist_y.sorted(by: >)
        dist_z = dist_z.sorted(by: >)
        
        let maxX = dist_x[0]
        let maxY = dist_y[0]
        let maxZ = dist_z[0]
        
        let objectBoundaries = ObjectBoundaries(maxX: maxX, maxY: maxY, maxZ: maxZ)
        
        return (SCNVector3(xC,yC,zC), objectBoundaries )
    }
    func plot_polygon(vertices: [SCNVector3], indices : [Int32]){
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexData = Data(bytes: indices,
                             count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .polygon,
                                         primitiveCount: 1,
                                         bytesPerIndex: MemoryLayout<Int32>.size)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.purple.withAlphaComponent(0.75)
        // Uncomment for clear plane
        //material.colorBufferWriteMask = []
        material.isDoubleSided = true
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.renderingOrder = -1
        self.sceneView.scene.rootNode.addChildNode(node)
    }


    func placePlaneInFrontOfObjects(index: Int) {
        for i in 0...self.realWorldObjectArray[index].count-1{
            self.indices.append(Int32(i))
            x = x+self.realWorldObjectArray[index][i].x
            y = y+self.realWorldObjectArray[index][i].y
            z = z+self.realWorldObjectArray[index][i].z
        }
        self.indices.insert(Int32(realWorldObjectArray[index].count), at: 0)
        plot_polygon(vertices:realWorldObjectArray[index] , indices: self.indices)
        self.indices = []
        
    }
    
    func getHeightBasedOnOrientation(objectBoundaries: ObjectBoundaries, eulerAngle: SCNVector3) -> CGFloat {
        
        //Get Orientation
        //If orientation is straight - OK x and y
        //else show x and z
        let xDegree = GLKMathRadiansToDegrees(eulerAngle.x)
        let normalisedX = 90 - abs(xDegree)
        
        if( normalisedX < abs(xDegree)){
            return CGFloat(objectBoundaries.getMaxZ())
        }
        else{
            return CGFloat(objectBoundaries.getMaxY())
        }
    }
    
    func getAllPlanesToRender(){
        
    }
    
    func isScanningComplete() -> Bool {
        return self.scanningComplete;
    }
    
    func _onScanningComplete() {
        self.scanningComplete = true
        //Add the scanned object to the realWorldObjectArray
        
        self.realWorldObjectArray.insert(self.vertices, at: self.objectCount)
        //self.realWorldObjectEulerArray.insert( self.lastEulerAngleDetetedForObject , at: self.objectCount)
        self.vertices.removeAll()
    }
    
    func _onScanningStart() {
        self.scanningComplete = false
        self.objectCount += 1
    }
    
    @IBAction func onStartScanningClick(_ sender: Any) {
        print("Start Tap Button Clicked")
        self.startButtonObject.isEnabled = false
        self.stopButtonObject.isEnabled = true
        self.showAllModelledObjButton.isEnabled = false
        self._onScanningStart()
    }

    
    @IBAction func onStopScanningClick(_ sender: Any) {
        print("End Tap Button Clicked")
        if(isScanningComplete()){
            return
    }
    

        self.startButtonObject.isEnabled = true
        self.stopButtonObject.isEnabled = false
        self.showAllModelledObjButton.isEnabled = true
        self._onScanningComplete()
    }
    
    @IBAction func onShowAllModelledObjectsClick(_ sender: Any) {
        if(self.startButtonObject.isEnabled == false){
            self.destroyAllModelledObjects();
            self.startButtonObject.isEnabled = true
            return
        }
        
        self.showAllModelledObjects()
        self.startButtonObject.isEnabled = false
        self.stopButtonObject.isEnabled = false
    }
   
    func destroyAllModelledObjects(){
        
    }
    
}

//Function to define "+" sign to add POV and Orentation = Location
func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}





/*
 
 Extra - Old Code

 
 /*
 //Function for timer in the game
 @objc func game(){
 
 
 if gameInt <= 0{
 gameTimer.invalidate()
 return
 }else{
 gameInt -= 1
 timeLabel.text = " "+String(gameInt)+"    "
 }
 
 }
 */
 
 
 
 //Max game time default 30sec
 //var gameInt = 30
 //Timer function to set game time limit
 //var gameTimer = Timer()
 
 //Oreintation Button toggle
 
 //toggle to turn on/off the timer
 //var timerToggle: Bool = false
 
 //Time label to show time remianing
 //@IBOutlet var timeLabel: UILabel!
 
 
 //@IBOutlet var progressBar: CircularProgressBar!
 
 */
