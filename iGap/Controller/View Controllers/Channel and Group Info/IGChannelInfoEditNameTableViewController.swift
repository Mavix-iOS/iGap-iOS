/*
 * This is the source code of iGap for iOS
 * It is licensed under GNU AGPL v3.0
 * You should have received a copy of the license in this archive (see LICENSE).
 * Copyright © 2017 , iGap - www.iGap.net
 * iGap Messenger | Free, Fast and Secure instant messaging application
 * The idea of the RooyeKhat Media Company - www.RooyeKhat.co
 * All rights reserved.
 */

import UIKit
import ProtocolBuffers
import RealmSwift
import MBProgressHUD
import IGProtoBuff

class IGChannelInfoEditNameTableViewController: UITableViewController , UITextFieldDelegate, UIGestureRecognizerDelegate {

  
    @IBOutlet weak var channelNameTextField: UITextField!
    @IBOutlet weak var numberOfCharacter: UILabel!
    var room : IGRoom?
    var hud = MBProgressHUD()
    override func viewDidLoad() {
        super.viewDidLoad()
        channelNameTextField.delegate = self
        channelNameTextField.becomeFirstResponder()
        self.tableView.backgroundView = UIImageView(image: UIImage(named: "IG_Settigns_Bg"))
        let navigationItem = self.navigationItem as! IGNavigationItem
        navigationItem.addNavigationViewItems(rightItemText: "Done", title: "Name")
        navigationItem.navigationController = self.navigationController as! IGNavigationController
        let navigationController = self.navigationController as! IGNavigationController
        navigationController.interactivePopGestureRecognizer?.delegate = self
        navigationItem.rightViewContainer?.addAction {
            self.changeChanellName()
        }
        if room != nil {
            channelNameTextField.text = room?.title
            
        }
        channelNameTextField.tintColor = UIColor.organizationalColor()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }
    func changeChanellName() {
        self.hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        self.hud.mode = .indeterminate
        if let name = channelNameTextField.text {
            IGChannelEditRequest.Generator.generate(roomId: (room?.id)!, channelName: name, description: nil).success({ (protoResponse) in
                DispatchQueue.main.async {
                    switch protoResponse {
                    case let editChannelResponse as IGPChannelEditResponse:
                        let channelName = IGChannelEditRequest.Handler.interpret(response: editChannelResponse)
                        self.channelNameTextField.text = channelName.channelName
                        self.hud.hide(animated: true)
                        if self.navigationController is IGNavigationController {
                            self.navigationController?.popViewController(animated: true)
                        }

                    default:
                        break
                    }
                }
            }).error ({ (errorCode, waitTime) in
                switch errorCode {
                case .timeout:
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Timeout", message: "Please try again later", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(okAction)
                        self.hud.hide(animated: true)
                        self.present(alert, animated: true, completion: nil)
                    }
                default:
                    break
                }
                
            }).send()
            
        }
    }
        
}

