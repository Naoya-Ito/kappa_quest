// ゲーム画面
import SpriteKit
import GameplayKit
import AVFoundation

class GameScene: BaseScene, SKPhysicsContactDelegate, AVAudioPlayerDelegate  {

    // 各種モデル
    private var enemyModel : EnemyModel = EnemyModel()
    private var actionModel : ActionModel = ActionModel()
    var gameData : GameData = GameData()
    var map : Map = Map()
    var jobModel : JobModel = JobModel()
    var skillModel : SkillModel = SkillModel()
    
    // Node
    private var tapNode : TapNode?  // タップ時に発生するノード
    var kappa : KappaNode?   // かっぱ画像
    private var sword : SwordNode?   // 剣
    private var underground : SKShapeNode?   // 地面
    
    private var kappa_first_position_y : CGFloat!
    
    private var isSceneDidLoaded = false
    
    // その他変数
    var gameOverFlag = false

    
    // Scene load 時に呼ばれる
    override func sceneDidLoad() {
        
        // 二重読み込みの防止
        if isSceneDidLoaded {
            return
        } else {
            isSceneDidLoaded = true
        }

        self.lastUpdateTime = 0
        
        self.physicsWorld.contactDelegate = self
        // データをセット
        enemyModel.readDataByPlist()
        jobModel.readDataByPlist()
        jobModel.loadParam()
        skillModel.readDataByPlist()
        actionModel.setActionData(sceneWidth: self.size.width)
        createKappa()
        map.readDataByPlist()
        map.loadParameterByUserDefault()
        createMap()
        gameData.setParameterByUserDefault()
        createTapNode()
        updateStatus()
        updateDistance()
        
        setHealVal()
        
        // 音楽関係の処理
        prepareBGM(fileName: Const.bgm_fantasy)
        prepareSoundEffect()
        playBGM()
        
        showMessage("冒険の始まりだ！", type: "start")
    }
    
    // 画面が読み込まれた時に呼ばれる
    override func didMove(to view: SKView) {
        updateStatus()
    }
    
    // かっぱ画像にphysic属性を与える
    func createKappa(){
        self.kappa = self.childNode(withName: "//kappa") as? KappaNode
        kappa?.setParameterByUserDefault()
        kappa?.setPhysic()
        kappa_first_position_y = kappa?.position.y
        setFirstPosition()
    }
    
    // 左からpos番目のx座標を返す
    func getPositionX(_ pos : Int) -> CGFloat {
        let position = CGFloat(pos)/7.0-1.0/2.0
        return self.size.width*position
    }
    
    // カッパを初期ポジションに設置
    func setFirstPosition(){
        map.myPosition = 1
        kappa?.position.x = getPositionX(1)
        kappa?.position.y = kappa_first_position_y
        kappa?.texture = SKTexture(imageNamed: "kappa")
    }
    
    // カッパを右端ポジションに設置
    func setRightPosition(){
        map.myPosition = Const.maxPosition - 1
        kappa?.position.x = getPositionX(Const.maxPosition - 1)
    }
    
    // タップ時に発生させるノード作成（初回のみ１回）
    func createTapNode(){
        let size = (self.size.width + self.size.height) * 0.005
        tapNode = tapNode?.makeNode(size: size)
    }
    
    func createShop(pos : Int){
        let shop = ShopNode.makeShop()
        shop.position = CGPoint(x: getPositionX(pos), y: (kappa?.position.y)!)
        shop.name = "shop"
        self.addChild(shop)
    }
    
    func saveData(){
        kappa?.saveParam()
        gameData.saveParam()
        jobModel.saveParam()
        map.saveParam()
    }
    
    // 右へ移動
    func moveRight(){
        if map.isMoving {
            return
        }
        map.isMoving = true
        kappa?.xScale = 1
        kappa?.walk()
        map.myPosition += 1
        
        kappa?.run(actionModel.moveRight!, completion: {() -> Void in
            if self.map.myPosition == Const.maxPosition {
                self.goNextMap()
            } else {
                self.updateButtonByPos()
            }
            self.map.isMoving = false
        })
    }
    
    // マップを右に移動
    func goNextMap(){
        clearMap()
        setFirstPosition()
        map.goNextMap()
        saveData()
        createMap()
        updateDistance()
    }
    
    // 左へ移動
    func moveLeft(){
        if map.isMoving {
            return
        }
        map.isMoving = true
        kappa?.xScale = -1
        kappa?.walk()
        
        map.myPosition -= 1
        kappa?.run(actionModel.moveLeft!, completion: {() -> Void in
            self.map.isMoving = false
            self.updateButtonByPos()
        })
    }
    
    // 現在位置によってボタン文言を変更
    func updateButtonByPos(){
        let ButtonNode  = childNode(withName: "//ButtonNode") as? SKSpriteNode
        let ButtonLabel = childNode(withName: "//ButtonLabel") as? SKLabelNode
        
        if map.isShop() {
            ButtonNode?.texture = SKTexture(imageNamed: "button_red")
            ButtonLabel?.text = "中に入る"
        } else {
            ButtonNode?.texture = SKTexture(imageNamed: "button_blue")
            ButtonLabel?.text = "メニューを開く"
        }
    }

    // 攻撃
    func attack(pos: Int){
        kappa?.attack()
        kappa?.run(actionModel.attack!, completion: {() -> Void in
            if self.enemyModel.enemies[pos].isDead {
                return
            }
            
            if BattleModel.isCritical(luc: Double((self.kappa?.pie)!)) {
                print("critical")
            } else {
                print("not critical")
            }
            
            
            let damage = BattleModel.calculateDamage(str: (self.kappa?.str)!, def: self.enemyModel.enemies[pos].def)
            let point = CGPoint(x: self.enemyModel.enemies[pos].position.x, y: self.enemyModel.enemies[pos].position.y + 30)
            self.displayDamage(value: damage, point: point, color: UIColor.white)
            self.makeSpark(point: CGPoint(x: self.enemyModel.enemies[pos].position.x, y: self.enemyModel.enemies[pos].position.y))
            
            self.playSoundEffect()
            
            self.enemyModel.enemies[pos].hp -= damage
            self.changeEnemyLifeBar(pos, per: self.enemyModel.enemies[pos].hp_per())
            
            if self.enemyModel.enemies[pos].hp <= 0 {
                self.beatEnemy(pos: pos)
            }
        })
    }
    
    // 攻撃をされた
    func attacked(attack:Int, type: String, point: CGPoint){
        var damage = 1
        if type == "magic" {
            damage = BattleModel.calculateDamage(str: attack, def: (kappa?.pie)!)
        } else {
            damage = BattleModel.calculateDamage(str: attack, def: (kappa?.def)!)
        }

        kappa?.hp -= damage
        if (kappa?.hp)! <= 0 {
            kappa?.hp = 0
        }
        
        displayDamage(value: damage, point: CGPoint(x:point.x-30, y:point.y+30), color: UIColor.red, direction: "left")
        updateStatus()
        
        if (kappa?.hp)! == 0 {
            gameOver()
        }
    }
    
    func makeSpark(point : CGPoint){
        let particle = SparkEmitterNode.makeSpark()
        particle.position = point
        particle.run(actionModel.sparkFadeOut!)
        self.addChild(particle)
    }
    
    
    // ダメージを数字で表示
    func displayDamage(value: Int, point: CGPoint, color: UIColor, direction : String = "right"){
        let location = CGPoint(x: point.x, y: point.y + 30.0)
        let label = SKLabelNode(fontNamed: Const.damageFont)
        label.name = "damage_text"
        label.text = "\(value)"
        label.fontSize = Const.damageFontSize - 5
        label.position = location
        label.fontColor = color
        label.zPosition = 90
        label.alpha = 0.9
        self.addChild(label)

        let bg_label = SKLabelNode(fontNamed: Const.damageFont)
        bg_label.name = "bg_damage_text"
        bg_label.position = location
        bg_label.fontColor = .black
        bg_label.text = "\(value)"
        bg_label.fontSize = Const.damageFontSize
        bg_label.zPosition = 89
        self.addChild(bg_label)
        
        if direction == "left" {
            label.run(actionModel.displayDamaged!)
            bg_label.run(actionModel.displayDamaged!)
        } else if direction == "right" {
            label.run(actionModel.displayDamage!)
            bg_label.run(actionModel.displayDamage!)
        } else if direction == "up" {
            label.run(actionModel.displayHeal!)
            bg_label.run(actionModel.displayHeal!)
        }
    }
    
    func displayExp(value: Int, point: CGPoint){
        let label = SKLabelNode(fontNamed: Const.damageFont)
        label.name = "damage_text"
        label.text = "\(value) exp"
        label.fontSize = 24
        label.fontName = Const.pixelFont
        label.position = CGPoint(x: point.x, y: point.y + 30.0)
        label.fontColor = .black
        label.zPosition = 90
        label.alpha = 0.9
        self.addChild(label)
        label.run(actionModel.displayExp!)
    }
    
    
    // モンスター撃破処理
    func beatEnemy(pos: Int){
        enemyModel.enemies[pos].hp = 0
        enemyModel.enemies[pos].isDead = true
        let get_exp = enemyModel.enemies[pos].exp
        let enemy_pos = enemyModel.enemies[pos].position
        
        displayExp(value: get_exp, point: CGPoint(x: enemy_pos.x, y: enemy_pos.y + Const.enemySize))
        removeEnemyLifeBar(pos)
        enemyModel.enemies[pos].setBeatPhysic()
        
        map.positionData[pos] = "free"
        updateExp(get_exp)
        enemyModel.enemies[pos].run(actionModel.displayExp!)
    }
    
    // 経験値更新
    func updateExp(_ getExp : Int){
        kappa?.nextExp -= getExp
        if (kappa?.nextExp)! <= 0 {
            LvUp()
        }
        updateStatus()
    }
    
    func LvUp(){
        kappa?.LvUp(jobModel)
        showMessage("LVがあがった", type: "lv")
        
        let HPUpLabel      = childNode(withName: "//HPUpLabel") as? SKLabelNode
        let StrUpLabel     = childNode(withName: "//StrUpLabel") as? SKLabelNode
        let DefUpLabel     = childNode(withName: "//DefUpLabel") as? SKLabelNode
        let AgiUpLabel     = childNode(withName: "//AgiUpLabel") as? SKLabelNode
        let IntUpLabel     = childNode(withName: "//IntUpLabel") as? SKLabelNode
        let PieUpLabel     = childNode(withName: "//PieUpLabel") as? SKLabelNode
        let LucUpLabel     = childNode(withName: "//LucUpLabel") as? SKLabelNode
        
        if jobModel.hp != 0 {
            HPUpLabel?.isHidden = false
            HPUpLabel?.text = "+\(jobModel.hp)"
            HPUpLabel?.run(actionModel.fadeInOut!)
        }
        if jobModel.str != 0 {
            StrUpLabel?.isHidden = false
            StrUpLabel?.text = "+\(jobModel.str)"
            StrUpLabel?.run(actionModel.fadeInOut!)
        }
        if jobModel.def != 0 {
            DefUpLabel?.isHidden = false
            DefUpLabel?.text = "+\(jobModel.def)"
            DefUpLabel?.run(actionModel.fadeInOut!)
        }
        if jobModel.str != 0 {
            AgiUpLabel?.isHidden = false
            AgiUpLabel?.text = "+\(jobModel.agi)"
            AgiUpLabel?.run(actionModel.fadeInOut!)
        }
        if jobModel.int != 0 {
            IntUpLabel?.isHidden = false
            IntUpLabel?.text = "+\(jobModel.int)"
            IntUpLabel?.run(actionModel.fadeInOut!)
        }
        if jobModel.pie != 0 {
            PieUpLabel?.isHidden = false
            PieUpLabel?.text = "+\(jobModel.pie)"
            PieUpLabel?.run(actionModel.fadeInOut!)
        }
        if jobModel.luc != 0 {
            LucUpLabel?.isHidden = false
            LucUpLabel?.text = "+\(jobModel.luc)"
            LucUpLabel?.run(actionModel.fadeInOut!)
        }
        if jobModel.name == "priest" {
            heal_val = jobModel.lv
        }
    }
    
    // タップ数アップ
    // 40タップごとに僧侶のアビリティを発動
    func tapCountUp(){
        let TapCountLabel  = childNode(withName: "//TapCountLabel") as? SKLabelNode

        gameData.tapCount += 1
        TapCountLabel?.text = "\(gameData.tapCount)"
        if gameData.tapCount%Const.tapHealCount == 0 {
            healAbility()
        }
    }
    
    var heal_val = 0 // 回復量。毎回UserDefaultから読み込まないように変数で保持
    func healAbility(){
        if heal_val == 0 {
            return
        } else {
            kappa?.hp += heal_val
            displayDamage(value: heal_val, point: (kappa?.position)!, color: .green, direction: "up")
            updateStatus()
        }
    }
    
    func setHealVal(){
        heal_val = JobModel.getLV("priest")
    }

    /***********************************************************************************/
    /********************************** ゲームオーバー ************************************/
    /***********************************************************************************/
    
    func gameOver(){
        if gameOverFlag == false {
            showMessage("やられたー", type: "dead")
            kappa?.dead()
            kappa?.run(actionModel.dead!)
            
            gameOverFlag = true
            stopBGM()
            _ = CommonUtil.setTimeout(delay: 3.0, block: { () -> Void in
                self.goGameOver()
            })
        }
    }
    
    func resetData(){
        kappa?.hp = (kappa?.maxHp)!
        map.resetData()
        gameOverFlag = false
        clearMap()
        createMap()
        setFirstPosition()
        saveData()
        
        updateStatus()
        updateDistance()
    }
    

    /***********************************************************************************/
    /********************************** ライフバー  **************************************/
    /***********************************************************************************/

    func changeLifeBar(){
        let life_bar_yellow = self.childNode(withName: "//LifeBarYellow") as? SKSpriteNode
        let life_percentage = CGFloat((kappa?.hp)!)/CGFloat((kappa?.maxHp)!)
        life_bar_yellow?.size.width = Const.lifeBarWidth*life_percentage
    }
    
    /***********************************************************************************/
    /********************************** 敵を描画  ****************************************/
    /***********************************************************************************/
    func createEnemy(pos: Int){
        if map.enemies.count == 0 {
            return
        }
        
        let lv = CommonUtil.valueMin1(Int(map.distance*10.0) - CommonUtil.rnd(3))
        let enemy = enemyModel.getRnadomEnemy(map.enemies, lv : lv)
        enemy.position.x = getPositionX(pos)
        enemy.position.y = (kappa?.position.y)!
        addChild(enemy)

        createEnemyLv(enemy.lv, position: CGPoint(x: enemy.position.x, y: enemy.position.y + Const.enemySize + 20))
        createEnemyLifeBar(pos: pos, x: (enemy.position.x - Const.enemySize/2), y: enemy.position.y - 30)
        enemyModel.enemies[pos] = enemy
    }
    
    func createEnemyLv(_ val : Int, position: CGPoint){
        let lv = SKLabelNode(text: "LV\(val)")
        lv.fontName = Const.pixelFont
        lv.fontSize = 24
        lv.fontColor = .black
        lv.position = position
        addChild(lv)

        lv.run(actionModel.fadeOutQuickly!)
    }
    
    func createEnemyLifeBar(pos: Int, x: CGFloat, y: CGFloat){
        let lifeBarBackGround = SKSpriteNode(color: .black, size: CGSize(width: 90, height: 20))
        lifeBarBackGround.position = CGPoint(x: x, y: y)
        lifeBarBackGround.zPosition = 98
        lifeBarBackGround.name = "back_life_bar\(pos)"
        lifeBarBackGround.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        addChild(lifeBarBackGround)

        let lifeBar = SKSpriteNode(color: .yellow, size: CGSize(width: 90, height: 20))
        lifeBar.position = CGPoint(x: x, y: y)
        lifeBar.zPosition = 99
        lifeBar.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        lifeBar.name = "life_bar\(pos)"
        addChild(lifeBar)
    }
    
    func changeEnemyLifeBar(_ pos : Int, per : Double){
        let bar = childNode(withName: "//life_bar\(pos)") as? SKSpriteNode
        bar?.size.width = CGFloat(per)
    }
    
    func removeEnemyLifeBar(_ pos : Int){
        let bar = self.childNode(withName: "//life_bar\(pos)") as? SKSpriteNode
        bar?.removeFromParent()
        
        let barBackground = self.childNode(withName: "//back_life_bar\(pos)") as? SKSpriteNode
        barBackground?.removeFromParent()
    }
    
    /***********************************************************************************/
    /********************************** マップ更新  **************************************/
    /***********************************************************************************/

    // マップ作成
    func createMap(){
        map.updatePositionData()
        for (index, positionData) in map.positionData.enumerated() {
            switch positionData {
            case "enemy":
                createEnemy(pos: index)
            case "shop":
                createShop(pos: index)
            default:
                break
            }
        }
        
        changeBackGround()
        if map.isEvent && map.distance == map.maxDistance {
            displayBigMessage(str0: map.text0, str1: map.text1)
        }
    }
    
    func changeBackGround(){
        let background = self.childNode(withName: "//BackgroundNode") as? SKSpriteNode
        background?.texture = SKTexture(imageNamed: map.background)
    }
    

    
    // マップの情報を削除
    func clearMap(){
        enumerateChildNodes(withName: "*") { node, _ in
            if node.name == "enemy" || node.name == "shop" || node.name == "fire" || node.name == "damage_text" || node.name == "bg_damage_text" {
                node.removeFromParent()
            }
        }
        enemyModel.resetEnemies()
        
        for i in 0 ..< Const.maxPosition {
            removeEnemyLifeBar(i)
        }
        
        /*
         if let enemies = self.childNodes(withName: "enemy") {
         for enemy in enemies {
         enemy.removeFromParent()
         }
         }
         */
    }
    
    /***********************************************************************************/
    /********************************** 表示更新 *****************************************/
    /***********************************************************************************/

    // ステータス更新
    func updateStatus(){
        
        // ステータス表示
        if kappa!.hp >= kappa!.maxHp {
            kappa!.hp = kappa!.maxHp
        }

        let MAXHPLabel     = childNode(withName: "//MAXHPLabel") as? SKLabelNode
        let HPLabel        = childNode(withName: "//HPLabel") as? SKLabelNode
        let LVLabel        = childNode(withName: "//LVLabel") as? SKLabelNode
        let StrLabel       = childNode(withName: "//StrLabel") as? SKLabelNode
        let DefLabel       = childNode(withName: "//DefLabel") as? SKLabelNode
        let AgiLabel       = childNode(withName: "//AgiLabel") as? SKLabelNode
        let IntLabel       = childNode(withName: "//IntLabel") as? SKLabelNode
        let PieLabel       = childNode(withName: "//PieLabel") as? SKLabelNode
        let LucLabel       = childNode(withName: "//LucLabel") as? SKLabelNode
        let ExpLabel       = childNode(withName: "//ExpLabel") as? SKLabelNode
        
        HPLabel?.text  = "\(String(describing: kappa!.hp))"
        LVLabel?.text  = "LV  \(String(describing: kappa!.lv))"
        MAXHPLabel?.text = "HP  \(String(describing: kappa!.maxHp))"
        StrLabel?.text = "筋力  \(String(describing: kappa!.str))"
        DefLabel?.text = "体力  \(String(describing: kappa!.def))"
        AgiLabel?.text = "敏捷  \(String(describing: kappa!.agi))"
        IntLabel?.text = "知恵  \(String(describing: kappa!.int))"
        PieLabel?.text = "精神  \(String(describing: kappa!.pie))"
        LucLabel?.text = "幸運  \(String(describing: kappa!.luc))"
        ExpLabel?.text = "次のレベルまで　　\(String(describing: kappa!.nextExp))"

        // 職業情報
        let JobLVLabel     = childNode(withName: "//JobLVLabel") as? SKLabelNode
        let JobNameLabel   = childNode(withName: "//JobNameLabel") as? SKLabelNode

        JobNameLabel?.text = jobModel.displayName
        JobLVLabel?.text = "LV  \(jobModel.lv)"

        // タップ情報
        let TapCountLabel  = childNode(withName: "//TapCountLabel") as? SKLabelNode
        TapCountLabel?.text = "\(gameData.tapCount)"
        
        changeLifeBar()
    }
    
    // 距離情報の更新
    func updateDistance(){
        let distanceLabel    = childNode(withName: "//DistanceLabel") as? SKLabelNode
        let maxDistanceLabel = childNode(withName: "//MaxDistanceCountLabel") as? SKLabelNode

        distanceLabel?.text = "\(map.distance)km"
        maxDistanceLabel?.text = "\(map.maxDistance)"
    }
    
    /***********************************************************************************/
    /********************************** メッセージ処理 ************************************/
    /***********************************************************************************/
    // メッセージ表示
    var messages = [[String]]()
    var isShowingMessage = false
    
    func showMessage(_ text : String, type : String){
        messages.append([text, type])
    }
    
    func displayMessage(){
        isShowingMessage = true
        
        let MessageLabel   = childNode(withName: "//MessageLabel") as? SKLabelNode
        let MessageNode    = childNode(withName: "//MessageNode") as? SKShapeNode

        MessageLabel?.text = messages[0][0]
        MessageNode?.position.x += 100
        
        switch messages[0][1] {
        case "start":
            MessageLabel?.fontColor = UIColor.black
            MessageNode?.fillColor = UIColor.yellow
        case "lv":
            MessageLabel?.fontColor = UIColor.white
            MessageNode?.fillColor = UIColor.black
        case "dead":
            MessageLabel?.fontColor = UIColor.black
            MessageNode?.fillColor = UIColor.red
        default:
            print("unknown message type")
        }
        
        MessageNode?.run(actionModel.displayMessage!, completion: {() -> Void in
            self.messages.remove(at: 0)
            self.isShowingMessage = false
        })
    }
    
    func displayBigMessage(str0: String, str1: String){
        let bigMessageNode     = childNode(withName: "//BigMessageNode") as? SKSpriteNode
        let bigMessageLabel0   = childNode(withName: "//BigMessageLabel0") as? SKLabelNode
        let bigMessageLabel1   = childNode(withName: "//BigMessageLabel1") as? SKLabelNode
        
        bigMessageNode?.run(actionModel.displayBigMessage!)
        bigMessageLabel0?.text = str0
        bigMessageLabel1?.text = str1
    }
    
    /***********************************************************************************/
    /********************************** 画面遷移 ****************************************/
    /***********************************************************************************/
    
    // 店へ行く
    func goShop(){
        let scene = ShopScene(fileNamed: "ShopScene")
        scene!.backScene = self.scene as! GameScene
        scene!.size = self.scene!.size
        scene!.scaleMode = SKSceneScaleMode.aspectFill
        self.view!.presentScene(scene!, transition: .doorway(withDuration: Const.doorTransitionInterval))
    }
    
    // メニュー画面へ遷移
    func goMenu(){
        let scene = MenuScene(fileNamed: "MenuScene")
        scene?.size = self.scene!.size
        scene?.scaleMode = SKSceneScaleMode.aspectFill
        scene?.backScene = self.scene as! GameScene
        self.view!.presentScene(scene!, transition: .fade(withDuration: Const.transitionInterval))
    }
    
    // ゲームオーバー画面へ
    func goGameOver(){
        let scene = GameOverScene(fileNamed: "GameOverScene")
        scene?.size = self.scene!.size
        scene?.scaleMode = SKSceneScaleMode.aspectFill
        scene?.backScene = self.scene as! GameScene
        self.view!.presentScene(scene!, transition: .fade(with: .white, duration: Const.gameOverInterval))
    }
    

    /***********************************************************************************/
    /********************************** touch ******************************************/
    /***********************************************************************************/
    
    func touchDown(atPoint pos : CGPoint) {
        if gameOverFlag {
            return
        }
        
        if let n = self.tapNode?.copy() as! SKShapeNode? {
            n.position = pos
            n.strokeColor = SKColor.green
            self.addChild(n)
        }
        
        if pos.x >= 0 {
            if map.canMoveRight() {
                moveRight()
            } else {
                attack(pos: map.myPosition+1)
            }
        } else {
            if map.canMoveLeft() {
                moveLeft()
            } else {
                kappa!.run(actionModel.moveBack!)
            }
        }
    }
    
    // 押し続け地得る時の処理
    func touchMoved(toPoint pos : CGPoint) {
        // FIXME
        return
/*
        if isMoving {
            return
        }
        if pos.x >= 0 {
            if map.canMoveRight() {
                moveRight()
            } else {
                attack(pos: map.myPosition+1)
            }
        } else {
            moveLeft()
        }
 */
    }
    
    func touchUp(atPoint pos : CGPoint) {
        if gameOverFlag {
            return
        }

        if let n = self.tapNode?.copy() as! SKShapeNode? {
            n.position = pos
            n.strokeColor = SKColor.red
            self.addChild(n)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        tapCountUp()
        
        if gameOverFlag {
            return
        }
        if map.myPosition+1 > Const.maxPosition {
            return
        }
        for t in touches {
            let positionInScene = t.location(in: self)
            let tapNode = self.atPoint(positionInScene)
            if tapNode.name == "ButtonNode" || tapNode.name == "ButtonLabel" {
                if map.isShop() {
                    goShop()
                } else {
                    goMenu()
                }
            } else if tapNode.name == "KappaInfoLabel" || tapNode.name == "KappaInfoNode" {
                displayAlert("ステータス", message: JobModel.allSkillExplain(skillModel), okString: "閉じる")
            } else {
                self.touchDown(atPoint: positionInScene)
            }
        }        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
//        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    /***********************************************************************************/
    /********************************** music ******************************************/
    /***********************************************************************************/
    var _audioPlayer:AVAudioPlayer!

    func prepareBGM(fileName : String){
        let bgm_path = NSURL(fileURLWithPath: Bundle.main.path(forResource: fileName, ofType: "mp3")!)
        var audioError:NSError?
        do {
            _audioPlayer = try AVAudioPlayer(contentsOf: bgm_path as URL)
        } catch let error as NSError {
            audioError = error
            _audioPlayer = nil
        }
        if let error = audioError {
            print("Error \(error.localizedDescription)")
        }
        _audioPlayer.delegate = self
        _audioPlayer.prepareToPlay()
    }
    
    func playBGM(){
        if !gameData.bgmFlag {
            return
        }
        _audioPlayer.numberOfLoops = -1;
        if ( !_audioPlayer.isPlaying ){
            _audioPlayer.play()
        }
    }
    
    func stopBGM(){
        if ( _audioPlayer.isPlaying ){
            _audioPlayer.stop()
        }
    }
    
    var _audioSoundEffect : AVAudioPlayer!
    func prepareSoundEffect(){
        let bgm_path = NSURL(fileURLWithPath: Bundle.main.path(forResource: Const.sound_effect2, ofType: "mp3")!)
        var audioError:NSError?
        do {
            _audioSoundEffect = try AVAudioPlayer(contentsOf: bgm_path as URL)
        } catch let error as NSError {
            audioError = error
            _audioSoundEffect = nil
        }
        if let error = audioError {
            print("Error \(error.localizedDescription)")
        }
        _audioSoundEffect.delegate = self
        _audioSoundEffect.prepareToPlay()
    }
    
    func playSoundEffect(){
//        _audioSoundEffect.numberOfLoops = 1;
        _audioSoundEffect.currentTime = 0
//        if ( !_audioSoundEffect.isPlaying ){
            _audioSoundEffect.play()
//        }
    }
    
    func stopSoundEffect(){
        if ( _audioSoundEffect.isPlaying ){
            _audioSoundEffect.stop()
        }
    }

    
    
    /***********************************************************************************/
    /********************************** 衝突判定 ****************************************/
    /***********************************************************************************/
    
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody, secondBody: SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        if firstBody.node == nil || secondBody.node == nil {
            return
        }
        
        // 衝突判定
        if (firstBody.categoryBitMask & Const.kappaCategory != 0 ) {
            if secondBody.categoryBitMask & Const.fireCategory != 0 {
                let fire = secondBody.node as! FireEmitterNode
                attacked(attack: fire.damage, type: "magick", point: (firstBody.node?.position)!)
                makeSpark(point: (secondBody.node?.position)!)
                secondBody.node?.removeFromParent()
            } else if secondBody.categoryBitMask & Const.enemyCategory != 0 {
                let enemy = secondBody.node as! EnemyNode
                if enemy.isAttacking {
                    attacked(attack: enemy.str, type: "physic", point: (firstBody.node?.position)!)
                    makeSpark(point: (firstBody.node?.position)!)
                }
            }
        }
    }
    
    /***********************************************************************************/
    /********************************** update ******************************************/
    /***********************************************************************************/
    private var lastUpdateTime : TimeInterval = 0
    private var doubleTimer = 0.0 // 経過時間（小数点単位で厳密）
    
    override func update(_ currentTime: TimeInterval) {
        if !isShowingMessage && messages.count > 0 {
            displayMessage()
        }

        if gameOverFlag {
            return
        }
        
        if (self.lastUpdateTime == 0) {
            self.lastUpdateTime = currentTime
        }

        let dt = currentTime - self.lastUpdateTime
        self.lastUpdateTime = currentTime
        
        doubleTimer += dt
        if doubleTimer > 1.0 {
            doubleTimer = 0.0
        } else {
            return
        }
        
        for enemy in enemyModel.enemies {
            if enemy.isDead {
                continue
            }
            enemy.timerUp()
            if enemy.isAttack() {
                enemy.isAttacking = true
                enemy.run(actionModel.enemyAttack(range: CGFloat(enemy.range)))
                enemy.attackTimerReset()
                _ = CommonUtil.setTimeout(delay: 2*Const.enemyJump, block: { () -> Void in
                    enemy.isAttacking = false
                })
            } else if enemy.isFire() {
                enemy.run(actionModel.enemyJump!)
                enemy.makeFire()
                enemy.fire.position = CGPoint(x: enemy.position.x, y: enemy.position.y + 40 )
                self.addChild(enemy.fire)
                enemy.fire.shot()
                enemy.fireTimerReset()
            } else if enemy.jumpTimer%4 == 0 {
                enemy.run(actionModel.enemyMiniJump!)
                enemy.jumpTimerReset()
            }
        }
    }
}
