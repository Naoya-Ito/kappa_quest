// 一覧情報を表示するコントローラー
import Foundation
import UIKit

class ListViewController : BaseTableViewController {

    @IBOutlet weak var _tableView: UITableView!

    var chapter = 1
    var type = ""
    var world = ""
    private var enemy_data : NSDictionary!
    private var worldModel = WorldModel()

    // モンスター図鑑（一覧）
    private var enemy_array = [
        "hiyoko",
        "chibidora",
        "megane",
        "ghost",
        "wizard",
        "usagi",
        "knight",
        "arakure",
        "buffalo",
        "thief",
        "priest",
        "archer",
        "dancer",
        "skelton",
        "zombi",
        "miira",
        "necro",
        "fighter",
        "samurai",
        "ninja",
        "tokage",
        "cross",
        "angel",
        "assassin",
        "king",
        "maou"
    ]

    // モンスター図鑑（詳細）
    var enemy_name = ""
    private let library_section = ["名称", "説明", "能力", ""]
    private let LIBRARY_ENEMY_NAME = 0
    private let LIBRARY_ENEMY_EXPLAIN = 1
    private let LIBRARY_ENEMY_STATUS  = 2
    private let LIBRARY_ENEMY_BACK    = 3

    // 酒場
    private let barModel = BarModel()
    private let bar_section = ["酒場の店長K(タップで話しかける)", "常連たち(タップで話しかける)", "あなたの行動"]
    private var bar_people = ["megane"]
    private let BAR_MASTER = 0
    private let BAR_PEOPLE = 1
    private let BAR_BACK = 2
    private var talk_array = [0,0,0,0,0,0,0,0,0,0,0,0]
    
    // ステータス画面
    private let status_section = ["名前", "レベル", "ステータス", "職業固有スキル", "発動中のスキル", ""]
    private let STATUS_NAME = 0
    private let STATUS_LV = 1
    private let STATUS_STATUS = 2
    private let STATUS_OWN_SKILL = 3
    private let STATUS_GENERAL_SKILL = 4
    private let STATUS_BACK = 5

    // アップデート履歴
    private let update_section = ["", "2.0.0", "1.2.0", "1.1.0", "1.0.0", ""]
    private let UPDATE_BACK = 0
    private let UPDATE_V2_0_0 = 1
    private let UPDATE_V1_2_0 = 2
    private let UPDATE_V1_1_0 = 3
    private let UPDATE_V1_0_0 = 4
    private let UPDATE_BACK2 = 5
    private var updateModel = UpdateModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setData()
    }
    
    // 初期データをセット
    func setData(){
        switch type {
        case "enemies":
            let sections_array = ["", "モンスター一覧", ""]
            if world != "" {
                 worldModel.readDataByPlist()
                 worldModel.setData(world)
                 enemy_array = worldModel.enemies
            }
            setSections(sections_array)
        case "library":
            setSections(library_section)
            enemy_data = EnemyModel.getData(enemy_name)
        case "bar":
            setSections(bar_section)
            barModel.chapter = chapter
            barModel.readDataByPlist()
            setBarPeople()
            NotificationModel.resetBarCount()
        case "status":
            setSections(status_section)
        case "update":
            setSections(update_section)
            updateModel.readDataByPlist()
        default:
            break
        }
        setTableSetting(_tableView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        if type != "bar" {
            _tableView.reloadData()
        }
    }

    let bar1_list : [String] = [
        "miyuki",
        "gundom",
        "angel",
        "fighter",
        "wizard",
        "necro",
        "knight",
        "archer",
        "priest",
        "thief",
        "dancer",
        ]
    let bar2_list : [String] = [
        "priest",
        "angel",
        ]


    func setBarPeople(){
        if chapter == 1 {
            for name in bar1_list {
                if GameData.isClear(name) {
                    bar_people.append(name)
                }
            }
        } else if chapter == 2 {
            for name in bar2_list {
                if GameData.isClear(name) {
                    bar_people.append(name)
                }
            }
        }
    }
    
    // row count
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch type {
        case "enemies":
            if section == 0 || section == 2 {
                return 1
            } else {
                return enemy_array.count
            }
        case "library":
            return 1
        case "bar":
            if section == BAR_MASTER || section == BAR_BACK {
                return 1
            } else {
                return bar_people.count
            }
        case "status":
            return 1
        case "update":
            return 1
        default:
            return 0
        }
    }
    // cell に関するデータソースメソッド
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for:indexPath) as UITableViewCell
        cell.textLabel?.numberOfLines = 0
        switch type {
        case "enemies":
            if indexPath.section == 0 || indexPath.section == 2 {
                cell.textLabel?.text = "戻る"
                cell.imageView?.isHidden = true
            } else {
                let enemy = EnemyModel.getData(enemy_array[indexPath.row])
                cell.textLabel?.text = enemy.object(forKey: "name") as? String
                cell.imageView?.image = UIImage(named: enemy_array[indexPath.row])
                cell.imageView?.isHidden = false
            }
        case "library":
            switch indexPath.section {
            case LIBRARY_ENEMY_NAME:
                let enemy_displaya_name = enemy_data["name"] as! String
                cell.textLabel?.text = enemy_displaya_name
                cell.imageView?.image = UIImage(named: enemy_name)
                cell.imageView?.isHidden = false
            case LIBRARY_ENEMY_EXPLAIN:
                if enemy_data["explain"] != nil {
                    cell.textLabel?.text = enemy_data["explain"] as? String
                    cell.imageView?.isHidden = true
                } else {
                    cell.textLabel?.text = ""
                    cell.imageView?.isHidden = true
                }
            case LIBRARY_ENEMY_STATUS:
                cell.textLabel?.text = EnemyModel.displayStatus(enemy_name)
                cell.imageView?.isHidden = true
            case LIBRARY_ENEMY_BACK:
                cell.textLabel?.text = "戻る"
                cell.imageView?.isHidden = true
            default:
                break
            }
        case "bar":
            switch indexPath.section {
            case BAR_MASTER:
                if GameData.isClear("question") {
                    cell.textLabel?.text = "（まさか、メニュー画面のアレがバレたのか？）"
                    cell.imageView?.isHidden = false
                    cell.imageView?.image = UIImage(named: "master")
                } else {
                    let list = barModel.getList("master")
                    cell.textLabel?.text = list[CommonUtil.rnd(list.count)]
                    cell.imageView?.isHidden = false
                    cell.imageView?.image = UIImage(named: "master")
                }
            case BAR_PEOPLE:
                let people = bar_people[indexPath.row]
                let list = barModel.getList(people)
                cell.textLabel?.text = list[talk_array[indexPath.row]]
                cell.imageView?.isHidden = false
                cell.imageView?.image = UIImage(named: people)
            case BAR_BACK:
                cell.textLabel?.text = "もう帰る"
                cell.imageView?.isHidden = true
            default:
                break
            }
        case "status":
            let kappa = KappaNode()
            kappa.setParameterByChapter1()
            let gameData = GameData()
            gameData.setParameterByUserDefault()
            let jobModel = JobModel()
            jobModel.readDataByPlist(chapter)
            jobModel.loadParam(chapter)
            let skillModel = SkillModel()
            skillModel.readDataByPlist()

            switch indexPath.section {
            case STATUS_NAME:
                cell.textLabel?.text = gameData.displayName(jobModel.displayName)
                cell.imageView?.isHidden = true
            case STATUS_LV:
                cell.textLabel?.text = "Total LV\(kappa.lv)\n\(jobModel.displayName)LV\(jobModel.lv)"
                cell.imageView?.isHidden = true
                break
            case STATUS_STATUS:
                cell.textLabel?.text = kappa.displayStatus()
                cell.imageView?.isHidden = true
                break
            case STATUS_OWN_SKILL:
                cell.textLabel?.text = jobModel.own_skill
                cell.imageView?.isHidden = true
                break
            case STATUS_GENERAL_SKILL:
                cell.textLabel?.text = JobModel.allSkillExplain(skillModel, kappa: kappa, gameData: gameData)
                cell.imageView?.isHidden = true
                break
            case STATUS_BACK:
                cell.textLabel?.text = "戻る"
                cell.imageView?.isHidden = true
                break
            default:
                break
            }
        case "update":
            if indexPath.section == UPDATE_BACK || indexPath.section == UPDATE_BACK2 {
                cell.textLabel?.text = "戻る"
                cell.imageView?.isHidden = true
            } else {
                switch indexPath.section {
                case UPDATE_V1_0_0:
                    cell.textLabel?.text = updateModel.getHistory("1.0.0")
                case UPDATE_V1_1_0:
                    cell.textLabel?.text = updateModel.getHistory("1.1.0")
                case UPDATE_V1_2_0:
                    cell.textLabel?.text = updateModel.getHistory("1.2.0")
                case UPDATE_V2_0_0:
                    cell.textLabel?.text = updateModel.getHistory("2.0.0")
                default:
                    cell.textLabel?.text = ""
                }
                cell.imageView?.isHidden = true
            }
        default:
            break
        }
        return cell
    }

    // タップ時の処理
    var bar_tap_count = 0
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch type {
        case "enemies":
            if indexPath.section == 0 || indexPath.section == 2 {
                dismiss(animated: true, completion: nil)
            } else {
                enemy_name = enemy_array[indexPath.row]
                type = "library"
                setData()
                _tableView.reloadData()
            }
        case "library":
            if indexPath.section == LIBRARY_ENEMY_BACK {
                type = "enemies"
                setData()
                _tableView.reloadData()
            }
        case "bar":
            if indexPath.section == BAR_MASTER {
                bar_tap_count += 1
                if bar_tap_count >= 77 {
                    GameData.clearCountUp("question")
                }
                _tableView.reloadRows(at: [indexPath], with: .none)
            } else if indexPath.section == BAR_BACK {
                dismiss(animated: false, completion: nil)
            } else {
                let people = bar_people[indexPath.row]
                let list = barModel.getList(people)

                talk_array[indexPath.row] = CommonUtil.rnd(list.count)
                _tableView.reloadRows(at: [indexPath], with: .none)
            }
        case "status":
            if indexPath.section == STATUS_BACK {
                dismiss(animated: false, completion: nil)
            }
        case "update":
            if indexPath.section == UPDATE_BACK || indexPath.section == UPDATE_BACK2 {
                dismiss(animated: false, completion: nil)
            }
        default:
            break
        }
    }

    // cell の色表示
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        switch type {
        case "enemies":
            if indexPath.section == 0 || indexPath.section == 2 {
                cell.backgroundColor = CommonUtil.UIColorFromRGB(0xfff0f5)
                return
            }
        case "library":
            if indexPath.section == LIBRARY_ENEMY_BACK {
                cell.backgroundColor = CommonUtil.UIColorFromRGB(0xfff0f5)
                return
            }
        case "bar":
            if indexPath.section == BAR_BACK {
                cell.backgroundColor = CommonUtil.UIColorFromRGB(0xfff0f5)
            } else if indexPath.section == BAR_PEOPLE {
                switch talk_array[indexPath.row] {
                case 0:
                    cell.backgroundColor = .white
                case 1:
                    cell.backgroundColor = .magenta
                case 2:
                    cell.backgroundColor = .orange
                case 3:
                    cell.backgroundColor = .yellow
                case 4:
                    cell.backgroundColor = .lightGray
                case 5:
                    cell.backgroundColor = .cyan
                case 6:
                    cell.backgroundColor = .red
                case 7:
                    cell.backgroundColor = .green
                default:
                    cell.backgroundColor = .white
                }
                return
            } else if indexPath.section == BAR_MASTER {
                if GameData.isClear("question") {
                    cell.backgroundColor = .black
                    cell.textLabel?.textColor = .white
                    return
                } else {
                    cell.textLabel?.textColor = .black
                }
            } else if indexPath.section == BAR_BACK {
                cell.textLabel?.textColor = .black
            } else {
                cell.textLabel?.textColor = .black                
            }
            return
        case "status":
            if indexPath.section == STATUS_BACK {
                cell.backgroundColor = CommonUtil.UIColorFromRGB(0xfff0f5)
                return
            }
        case "update":
            if indexPath.section == UPDATE_BACK || indexPath.section == UPDATE_BACK2 {
                cell.backgroundColor = CommonUtil.UIColorFromRGB(0xfff0f5)
                return
            }

        default:
            break
        }
        cell.backgroundColor = UIColor.white
    }
}
