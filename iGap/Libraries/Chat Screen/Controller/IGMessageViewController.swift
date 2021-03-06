//
//  IGMessageViewController.swift
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
import IGProtoBuff
import ProtocolBuffers
import GrowingTextView
import pop
import SnapKit
import AVFoundation
import DBAttachmentPickerControllerLibrary
import INSPhotoGalleryFramework
import AVKit
import RealmSwift
import RxRealm
import RxSwift
import RxCocoa
import MBProgressHUD

class IGHeader: UICollectionReusableView {
    
    override var reuseIdentifier: String? {
        get {
            return "IGHeader"
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.red
        
        let label = UILabel(frame: frame)
        label.text = "sdasdasdasd"
        self.addSubview(label)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}

class IGMessageViewController: UIViewController, DidSelectLocationDelegate , UIGestureRecognizerDelegate {

    @IBOutlet weak var collectionView: IGMessageCollectionView!
    @IBOutlet weak var inputBarContainerView: UIView!
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var inputTextView: GrowingTextView!
    @IBOutlet weak var inputTextViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputBarHeightContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputBarView: UIView!
    @IBOutlet weak var inputBarBackgroundView: UIView!
    @IBOutlet weak var inputBarLeftView: UIView!
    @IBOutlet weak var inputBarRightiew: UIView!
    @IBOutlet weak var inputBarViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputBarRecordButton: UIButton!
    @IBOutlet weak var inputBarSendButton: UIButton!
    @IBOutlet weak var inputBarRecordTimeLabel: UILabel!
    @IBOutlet weak var inputBarRecordView: UIView!
    @IBOutlet weak var inputBarRecodingBlinkingView: UIView!
    @IBOutlet weak var inputBarRecordRightView: UIView!
    @IBOutlet weak var inputBarRecordViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputBarAttachmentView: UIView!
    @IBOutlet weak var inputBarAttachmentViewThumnailImageView: UIImageView!
    @IBOutlet weak var inputBarAttachmentViewFileNameLabel: UILabel!
    @IBOutlet weak var inputBarAttachmentViewFileSizeLabel: UILabel!
    @IBOutlet weak var inputBarAttachmentViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputBarOriginalMessageView: UIView!
    @IBOutlet weak var inputBarOriginalMessageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputBarOriginalMessageViewSenderNameLabel: UILabel!
    @IBOutlet weak var inputBarOriginalMessageViewBodyTextLabel: UILabel!
    @IBOutlet weak var scrollToBottomContainerView: UIView!
    
    private let disposeBag = DisposeBag()
    var isFetchingRoomHistory: Bool = false
    var isInMessageViewController : Bool = true
    var recorder: AVAudioRecorder?
    var isRecordingVoice = false
    var voiceRecorderTimer: Timer?
    var recordedTime: Int = 0
    var inputTextViewHeight: CGFloat = 0.0
    var inputBarRecordRightBigViewWidthConstraintInitialValue: CGFloat = 0.0
    var inputBarRecordRightBigViewInitialFrame = CGRect(x: 0, y: 0, width: 0, height: 0)
    var bouncingViewWhileRecord: UIView?
    var initialLongTapOnRecordButtonPosition: CGPoint?
    var collectionViewTopInsetOffset: CGFloat = 0.0
    
    
    //var messages = [IGRoomMessage]()
    let sortProperties = [SortDescriptor(keyPath: "creationTime", ascending: false),
                          SortDescriptor(keyPath: "id", ascending: false)]
    let sortPropertiesForMedia = [SortDescriptor(keyPath: "creationTime", ascending: true),
                                  SortDescriptor(keyPath: "id", ascending: true)]
    var messages: Results<IGRoomMessage>? //try! Realm().objects(IGRoomMessage.self)
    var messagesWithMedia = try! Realm().objects(IGRoomMessage.self)
    var messagesWithForwardedMedia = try! Realm().objects(IGRoomMessage.self)
    var notificationToken: NotificationToken?
    
    var messageCellIdentifer = IGMessageCollectionViewCell.cellReuseIdentifier()
    var logMessageCellIdentifer = IGMessageLogCollectionViewCell.cellReuseIdentifier()
    var room : IGRoom?
    //let currentLoggedInUserID = IGAppManager.sharedManager.userID()
    let currentLoggedInUserAuthorHash = IGAppManager.sharedManager.authorHash()
    
    var selectedMessageToEdit: IGRoomMessage?
    var selectedMessageToReply: IGRoomMessage?
    var selectedMessageToForwardToThisRoom:   IGRoomMessage?
    var selectedMessageToForwardFromThisRoom: IGRoomMessage?
    var currentAttachment: IGFile?
    var selectedUserToSeeTheirInfo: IGRegisteredUser?
    var selectedChannelToSeeTheirInfo: IGChannelRoom?
    var selectedGroupToSeeTheirInfo: IGGroupRoom?
    var hud = MBProgressHUD()

    fileprivate var typingStatusExpiryTimer = Timer() //use this to send cancel for typing status
    
    //MARK: - Initilizers
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addNotificationObserverForTapOnStatusBar()
        var canBecomeFirstResponder: Bool { return true }
        let navigationItem = self.navigationItem as! IGNavigationItem
        navigationItem.setNavigationBarForRoom(room!)
        navigationItem.navigationController = self.navigationController as! IGNavigationController
        let navigationController = self.navigationController as! IGNavigationController
        navigationController.interactivePopGestureRecognizer?.delegate = self
        navigationItem.rightViewContainer?.addAction {
            if self.room?.type == .chat {
                self.selectedUserToSeeTheirInfo = (self.room?.chatRoom?.peer)!
                self.performSegue(withIdentifier: "showUserInfo", sender: self)
            }
            if self.room?.type == .channel {
                self.selectedChannelToSeeTheirInfo = self.room?.channelRoom
                self.performSegue(withIdentifier: "showChannelinfo", sender: self)
            }
            if self.room?.type == .group {
                self.selectedGroupToSeeTheirInfo = self.room?.groupRoom
                self.performSegue(withIdentifier: "showGroupInfo", sender: self)
            }
            
        }
        navigationItem.centerViewContainer?.addAction {
            if self.room?.type == .chat {
                self.selectedUserToSeeTheirInfo = (self.room?.chatRoom?.peer)!
                self.performSegue(withIdentifier: "showUserInfo", sender: self)
            } else {
                
            }
        }
        
        
        if room!.isReadOnly {
            if room!.isParticipant == false {
                inputBarContainerView.isHidden = true
                joinButton.isHidden = false
            } else {
                inputBarContainerView.isHidden = true
                collectionViewTopInsetOffset = -54.0 + 8.0
            }
        } else {
            
        }
        
        

        
        
//        let predicate = NSPredicate(format: "roomId = %d AND isDeleted == false", self.room!.id)
//        messages = try! Realm().objects(IGRoomMessage.self).filter(predicate).sorted(byProperty: "creationTime")
//        messages = try! IGFactory.shared.realm.objects(IGRoomMessage.self).filter(predicate).sorted(byProperty: "creationTime")
        
        let messagesWithMediaPredicate = NSPredicate(format: "roomId = %lld AND isDeleted == false AND (typeRaw = %d OR typeRaw = %d)", self.room!.id, IGRoomMessageType.image.rawValue, IGRoomMessageType.imageAndText.rawValue)
        messagesWithMedia = try! Realm().objects(IGRoomMessage.self).filter(messagesWithMediaPredicate).sorted(by: sortPropertiesForMedia)
        
        let messagesWithForwardedMediaPredicate = NSPredicate(format: "roomId = %lld AND isDeleted == false AND (forwardedFrom.typeRaw == 1 OR forwardedFrom.typeRaw == 2 OR forwardedFrom.typeRaw == 3 OR forwardedFrom.typeRaw == 4)", self.room!.id)
        messagesWithForwardedMedia = try! Realm().objects(IGRoomMessage.self).filter(messagesWithForwardedMediaPredicate).sorted(by: sortPropertiesForMedia)
        
        self.collectionView.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
        self.collectionView.delaysContentTouches = false
        self.collectionView.keyboardDismissMode = .none
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        
        
        self.view.backgroundColor = UIColor.white
        self.view.superview?.backgroundColor = UIColor.white
        self.view.superview?.superview?.backgroundColor = UIColor.white
        self.view.superview?.superview?.superview?.backgroundColor = UIColor.white
        self.view.superview?.superview?.superview?.superview?.backgroundColor = UIColor.white
        
        
        let inputTextViewInitialHeight:CGFloat = 22.0 //initial without reply || forward || attachment || text
        self.inputTextViewHeight = inputTextViewInitialHeight
        self.setInputBarHeight()
        
        
        inputTextView.delegate = self
        inputTextView.placeHolder = "Write here ..."
        inputTextView.placeHolderColor = UIColor(red: 173.0/255.0, green: 173.0/255.0, blue: 173.0/255.0, alpha: 1.0)
        inputTextView.maxHeight = 83.0 // almost 4 lines
        inputTextView.contentInset = UIEdgeInsets(top: -5, left: 0, bottom: -5, right: 0)
        
        
        inputBarLeftView.layer.cornerRadius = 19.0
        inputBarLeftView.layer.masksToBounds = true
        inputBarRightiew.layer.cornerRadius = 19.0
        inputBarRightiew.layer.masksToBounds = true
        
        
        inputBarBackgroundView.layer.cornerRadius = 19.0
        inputBarBackgroundView.layer.masksToBounds = false
        inputBarBackgroundView.layer.shadowColor = UIColor.black.cgColor
        inputBarBackgroundView.layer.shadowOffset = CGSize(width: 0, height: 0)
        inputBarBackgroundView.layer.shadowRadius = 4.0
        inputBarBackgroundView.layer.shadowOpacity = 0.15
        inputBarBackgroundView.layer.borderColor = UIColor(red: 209.0/255.0, green: 209.0/255.0, blue: 209.0/255.0, alpha: 1.0).cgColor
        inputBarBackgroundView.layer.borderWidth  = 1.0
        
        inputBarView.layer.cornerRadius = 19.0
        inputBarView.layer.masksToBounds = true
        
        inputBarRecordView.layer.cornerRadius = 19.0
        inputBarRecordView.layer.masksToBounds = false
        inputBarRecodingBlinkingView.layer.cornerRadius = 8.0
        inputBarRecodingBlinkingView.layer.masksToBounds = false
        inputBarRecordRightView.layer.cornerRadius = 19.0
        inputBarRecordRightView.layer.masksToBounds = false
        
        inputBarRecordView.isHidden = true
        inputBarRecodingBlinkingView.isHidden = true
        inputBarRecordRightView.isHidden = true
        inputBarRecordTimeLabel.isHidden = true
        inputBarRecordTimeLabel.alpha = 0.0
        inputBarRecordViewLeftConstraint.constant = 200
        
        
        scrollToBottomContainerView.layer.cornerRadius = 20.0
        scrollToBottomContainerView.layer.masksToBounds = false
        scrollToBottomContainerView.layer.shadowColor = UIColor.black.cgColor
        scrollToBottomContainerView.layer.shadowOffset = CGSize(width: 0, height: 0)
        scrollToBottomContainerView.layer.shadowRadius = 4.0
        scrollToBottomContainerView.layer.shadowOpacity = 0.15
        scrollToBottomContainerView.backgroundColor = UIColor.white
        scrollToBottomContainerView.isHidden = true
        
        self.setCollectionViewInset()
        //Keyboard Notification
        
        notification(register: true)
        inputBarSendButton.isHidden = true
        
        
        let tapAndHoldOnRecord = UILongPressGestureRecognizer(target: self, action: #selector(didTapAndHoldOnRecord(_:)))
        tapAndHoldOnRecord.minimumPressDuration = 0.5
        inputBarRecordButton.addGestureRecognizer(tapAndHoldOnRecord)
        
        
        // Set messages notification block
        let predicate = NSPredicate(format: "roomId = %d AND isDeleted == false", self.room!.id)
        messages = try! Realm().objects(IGRoomMessage.self).filter(predicate).sorted(by: sortProperties)
        
        self.notificationToken = messages?.addNotificationBlock { (changes: RealmCollectionChange) in
            switch changes {
            case .initial:
                self.collectionView.alpha = 0.0
                self.collectionView.reloadData()
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.collectionView.alpha = 1.0
                })

                
                break
            case .update(_, let deletions, let insertions, let modifications):
                insertions.forEach{
                    if let message = self.messages?[$0] {
                        self.sendSeenForMessage(message)
                        print(message.status)
                    }
                }
                
                if self.messages!.count == self.collectionView.numberOfSections + insertions.count - deletions.count {
                    print("insersation   => \(insertions.count)")
                    print("deletions     => \(deletions.count)")
                    print("modifications => \(modifications.count)")
                    print("all messages  => \(self.messages!.count)")
                    
                    self.collectionView.performBatchUpdates({
                        self.collectionView.insertSections(IndexSet(insertions))
                        self.collectionView.deleteSections(IndexSet(deletions))
                        UIView.performWithoutAnimation {
                            self.collectionView.reloadSections(IndexSet(modifications))
                        }
                        //self.collectionView.reloadSections(IndexSet(modifications))
                        
                        
                        
//                        self.collectionView.insertItems(at: insertions.map    { IndexPath(row: 0, section: $0) })
//                        self.collectionView.deleteItems(at: deletions.map     { IndexPath(row: 0, section: $0) })
//                        self.collectionView.reloadItems(at: modifications.map { IndexPath(row: 0, section: $0) })
                        
//                        self.collectionView.insertItems(at: insertions.map    { IndexPath(row: $0, section: 0) })
//                        self.collectionView.deleteItems(at: deletions.map     { IndexPath(row: $0, section: 0) })
//                        self.collectionView.reloadItems(at: modifications.map { IndexPath(row: $0, section: 0) })
                    }, completion: { (completed) in
                        if insertions.count != 0 {
                            
                        }
                    })
                } else {
                    self.collectionView.reloadData()
                }
                
                break
            case .error(let err):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(err)")
                break
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let forwardMsg = selectedMessageToForwardToThisRoom {
            self.forwardMessage(forwardMsg)
        } else if let draft = self.room!.draft {
            if draft.message != "" || draft.replyTo != -1 {
                inputTextView.text = draft.message
                inputTextView.placeHolder = "Write here ..."
                if draft.replyTo != -1 {
                    let predicate = NSPredicate(format: "id = %lld AND roomId = %lld", draft.replyTo, self.room!.id)
                    if let replyToMessage = try! Realm().objects(IGRoomMessage.self).filter(predicate).first {
                        replyMessage(replyToMessage)
                    }
                }
                setSendAndRecordButtonStates()
            }
        }
        notification(register: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IGAppManager.sharedManager.currentMessagesNotificationToekn = self.notificationToken
        let navigationItem = self.navigationItem as! IGNavigationItem
//        _ = Observable.from(object: room!)
//            .subscribe(onNext: {aRoom in
//                print ("room changed")
//                
//            })
        
        
        if let roomVariable = IGRoomManager.shared.varible(for: room!) {
            roomVariable.asObservable().subscribe({ (event) in
                if event.element == self.room! {
                    DispatchQueue.main.async {
                        navigationItem.updateNavigationBarForRoom(event.element!)
                        
                    }
                }
            }).addDisposableTo(disposeBag)
//            _ = Observable.from(roomVariable).subscribe(onNext: { (roomVariable) in
//                print ("room changed")
//            }, onError: nil, onCompleted: nil, onDisposed: nil)
//            roomVariableFromRoomManagerCache = roomVariable
//            roomVariableFromRoomManagerCache?.asObservable().subscribe({ (event) in
//                DispatchQueue.main.async {
//                    if self.roomVariableFromRoomManagerCache?.value.id != room.id {
//                        return
//                    }
//                    navigationItem.updateNavigationBarForRoom(aRoom)
//                    
//                    
//                    
//                    
//                    
//                }
//            }).addDisposableTo(disposeBag)
        }
        
        
        AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
            
        }
        
        self.setMessagesRead()
        
    }
    

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IGAppManager.sharedManager.currentMessagesNotificationToekn = nil
        self.room!.saveDraft(inputTextView.text, replyToMessage: selectedMessageToReply)
        self.sendCancelTyping()
        self.isInMessageViewController = false
        self.sendCancelRecoringVoice()
        if let room = self.room {
            IGFactory.shared.markAllMessagesAsRead(roomId: room.id)

        }
    }
    
    deinit {
        notificationToken = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        //TODO: check performance
        self.collectionView!.collectionViewLayout.invalidateLayout()
    }
    
    
    
    
    
    //MARK - Send Seen Status
    private func setMessagesRead() {
        if let room = self.room {
            IGFactory.shared.markAllMessagesAsRead(roomId: room.id)
        }
        self.messages!.forEach{
            if let authorHash = $0.authorHash {
                if authorHash != self.currentLoggedInUserAuthorHash! {
                    self.sendSeenForMessage($0)
                }
            }
        }
    }
    
    private func sendSeenForMessage(_ message: IGRoomMessage) {
        if message.status == .seen {
            return
        }
        switch self.room!.type {
        case .chat:
            if isInMessageViewController {
                IGChatUpdateStatusRequest.Generator.generate(roomID: self.room!.id, messageID: message.id, status: .seen).success({ (responseProto) in
                    switch responseProto {
                    case let response as IGPChatUpdateStatusResponse:
                        IGChatUpdateStatusRequest.Handler.interpret(response: response)
                    default:
                        break
                    }
                }).error({ (errorCode, waitTime) in
                    
                }).send()
            }
        case .group:
            if isInMessageViewController {
                IGGroupUpdateStatusRequest.Generator.generate(roomID: self.room!.id, messageID: message.id, status: .seen).success({ (responseProto) in
                    switch responseProto {
                    case let response as IGPGroupUpdateStatusResponse:
                        IGGroupUpdateStatusRequest.Handler.interpret(response: response)
                    default:
                        break
                    }
                }).error({ (errorCode, waitTime) in
                    
                }).send()
            }
            break
        case .channel:
            if isInMessageViewController {
                if let message = self.messages?.last {
                    IGChannelGetMessagesStatsRequest.Generator.generate(messages: [message], room: self.room!).success({ (responseProto) in
                        
                    }).error({ (errorCode, waitTime) in
                        
                    }).send()
                }
            }
        }
    }
    
    func userWasSelectedLocation(location: CLLocation) {
        print(location)
    }

    //MARK: - Scroll
    func updateScrollPosition(forceToLastMessage: Bool, wasAddedMessagesNewer: Bool?, initialContentOffset: CGPoint?, initialContentSize: CGSize?, animated: Bool) {
//        if forceToBottom {
//            scrollToLastMessage(animated: animated)
//        } else {
//            let initalContentBottomPadding = (initialContentSize!.height + self.collectionView.contentInset.bottom) - (initialContentOffset!.y + self.collectionView.frame.height)
//            
//            //100 is an arbitrary number can be anything that makes sense. 100, 150, ...
//            //we used this to see if user is near the bottom of scroll view and 
//            //we should scrolll to bottom
//            if initalContentBottomPadding < 100 {
//                scrollToLastMessage(animated: animated)
//            } else {
//                if didMessagesAddedToBottom != nil {
//                    keepScrollPosition(didMessagesAddedToBottom: didMessagesAddedToBottom!, initialContentOffset: initialContentOffset!, initialContentSize: initialContentSize!, animated: animated)
//                }
//            }
//        }
    }
    
//    private func scrollToLastMessage(animated: Bool) {
//        if self.collectionView.numberOfItems(inSection: 0) > 0  {
////            let indexPath = IndexPath(row: self.collectionView.numberOfItems(inSection: 0)-1, section: 0)
//            let indexPath = IndexPath(row: 0, section: self.collectionView.numberOfItems(inSection: 0)-1)
//            self.collectionView.scrollToItem(at: indexPath, at: .bottom, animated: animated)
//        }
//    }
    
    private func keepScrollPosition(didMessagesAddedToBottom: Bool, initialContentOffset: CGPoint, initialContentSize: CGSize, animated: Bool) {
        if didMessagesAddedToBottom {
            self.collectionView.contentOffset = initialContentOffset
        } else {
            let contentOffsetY = self.collectionView.contentSize.height - (initialContentSize.height - initialContentOffset.y)
            // + self.collectionView.contentOffset.y - initialContentSize.height
            self.collectionView.contentOffset = CGPoint(x: self.collectionView.contentOffset.x, y: contentOffsetY)
        }
    }
    
    
    //MARK: -
    private func notification(register: Bool) {
        let center = NotificationCenter.default
        if register {
            center.addObserver(self,
                               selector: #selector(didReceiveKeyboardWillChangeFrameNotification(_:)),
                               name: NSNotification.Name.UIKeyboardWillHide,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(didReceiveKeyboardWillChangeFrameNotification(_:)),
                               name: NSNotification.Name.UIKeyboardWillChangeFrame,
                               object: nil)
            
            center.addObserver(self,
                               selector: #selector(dodd),
                               name: NSNotification.Name.UIMenuControllerWillShowMenu,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(dodd),
                               name: NSNotification.Name.UIMenuControllerWillHideMenu,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(dodd),
                               name: NSNotification.Name.UIContentSizeCategoryDidChange,
                               object: nil)
        } else {
            center.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
            center.removeObserver(self, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
            center.removeObserver(self, name: NSNotification.Name.UIMenuControllerWillShowMenu, object: nil)
            center.removeObserver(self, name: NSNotification.Name.UIMenuControllerWillHideMenu, object: nil)
            center.removeObserver(self, name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
        }
    }
    
    func dodd() {
    
    }
    
    func didReceiveKeyboardWillChangeFrameNotification(_ notification:Notification) {
        
        let userInfo = (notification.userInfo)!
        if let keyboardEndFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect {
            
            let animationCurve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as! Int
            let animationCurveOption = (animationCurve << 16)
            let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! Double
            let keyboardBeginFrame = userInfo[UIKeyboardFrameBeginUserInfoKey] as! CGRect
            
            var bottomConstraint: CGFloat
            if keyboardEndFrame.origin.y == keyboardBeginFrame.origin.y {
                return
            } else if notification.name == Notification.Name.UIKeyboardWillHide  {
                //hidding keyboard
                bottomConstraint = 0.0
            } else {
                //showing keyboard
                bottomConstraint = keyboardEndFrame.size.height
            }
            
            UIView.animate(withDuration: animationDuration, delay: 0.0, options: UIViewAnimationOptions(rawValue: UInt(animationCurveOption)), animations: {
                self.inputBarViewBottomConstraint.constant = bottomConstraint
                //self.setCollectionViewInset()
                self.view.layoutIfNeeded()
            }, completion: { (completed) in
                
            })
        }
    }
        
    func setCollectionViewInset() {
        let value = inputBarHeightContainerConstraint.constant + collectionViewTopInsetOffset// + inputBarViewBottomConstraint.constant
        UIView.animate(withDuration: 0.2, animations: {
            self.collectionView.contentInset = UIEdgeInsetsMake(value, 0, 20, 0)
        }, completion: { (completed) in
            
        })
    }
    
    //MARK: IBActions
    @IBAction func didTapOnSendButton(_ sender: UIButton) {
        if currentAttachment == nil && inputTextView.text == "" && selectedMessageToForwardToThisRoom == nil {
            return
        }
        
        
        if selectedMessageToEdit != nil {
            switch room!.type {
            case .chat:
                IGChatEditMessageRequest.Generator.generate(message: selectedMessageToEdit!, newText: inputTextView.text,  room: room!).success({ (protoResponse) in
                    IGChatEditMessageRequest.Handler.interpret(response: protoResponse)
                }).error({ (errorCode, waitTime) in
                    
                }).send()
            case .group:
                IGGroupEditMessageRequest.Generator.generate(message: selectedMessageToEdit!, newText: inputTextView.text, room: room!).success({ (protoResponse) in
                    switch protoResponse {
                    case let response as IGPGroupEditMessageResponse:
                        IGGroupEditMessageRequest.Handler.interpret(response: response)
                    default:
                        break
                    }
                }).error({ (errorCode, waitTime) in
                    
                }).send()
            case .channel:
                IGChannelEditMessageRequest.Generator.generate(message: selectedMessageToEdit!, newText: inputTextView.text, room: room!).success({ (protoResponse) in
                    switch protoResponse {
                    case let response as IGPChannelEditMessageResponse:
                        IGChannelEditMessageRequest.Handler.interpret(response: response)
                    default:
                        break
                    }
                }).error({ (errorCode, waitTime) in
                    
                }).send()
            }
            selectedMessageToEdit = nil
            self.inputTextView.text = ""
            self.setInputBarHeight()
            self.sendCancelTyping()
            return
        }
        
        let message = IGRoomMessage(body: inputTextView.text)
        
        if currentAttachment != nil {
            currentAttachment?.status = .processingForUpload
            message.attachment = currentAttachment?.detach()
            IGAttachmentManager.sharedManager.add(attachment: currentAttachment!)
            switch currentAttachment!.type {
            case .image:
                if inputTextView.text == "" {
                    message.type = .image
                } else {
                    message.type = .imageAndText
                }
            case .video:
                if inputTextView.text == "" {
                    message.type = .video
                } else {
                    message.type = .videoAndText
                }
            case .audio:
                if inputTextView.text == "" {
                    message.type = .audio
                } else {
                    message.type = .audioAndText
                }
            case .voice:
                message.type = .voice
            case .file:
                if inputTextView.text == "" {
                    message.type = .file
                } else {
                    message.type = .fileAndText
                }
            default:
                break
            }
        } else {
            message.type = .text
        }
        message.repliedTo = selectedMessageToReply
        message.forwardedFrom = selectedMessageToForwardToThisRoom

        message.roomId = self.room!.id
        
        let detachedMessage = message.detach()
        
        IGFactory.shared.saveNewlyWriitenMessageToDatabase(detachedMessage)
        IGMessageSender.defaultSender.send(message: message, to: room!)
        
        self.inputBarSendButton.isHidden = true
        self.inputBarRecordButton.isHidden = false
        self.inputTextView.text = ""
        self.selectedMessageToForwardToThisRoom = nil
        self.selectedMessageToReply = nil
        self.currentAttachment = nil
        self.setInputBarHeight()
    }
    
    
    @IBAction func didTapOnAddAttachmentButton(_ sender: UIButton) {
        self.inputTextView.resignFirstResponder()
        let contact = UIAlertAction(title: "Contact", style: .default, handler: { (action) in
        })
        let location = UIAlertAction(title: "Location", style: .default, handler: { (action) in
            let settingStoryBoard = UIStoryboard(name: "Main", bundle: nil)
            let setCurrentLocationTableViewController = settingStoryBoard.instantiateViewController(withIdentifier: "SetCurrentLocationPage") as! IGMessageAttachmentCurrentLocationViewController
            let modalStyle: UIModalTransitionStyle = UIModalTransitionStyle.coverVertical
            setCurrentLocationTableViewController.modalTransitionStyle = modalStyle
            let navigationBar = IGNavigationController(rootViewController: setCurrentLocationTableViewController)
            self.present(navigationBar, animated: true, completion: nil)

        })
        let customActions = [contact, location]
        
        let attachmentPickerController = DBAttachmentPickerController(customActions: nil, finishPicking: { (files) in
            //at phase 1 we only select one media
            if files.count > 0 {
                let selectedFile = files[0]
                
                let attachment = IGFile(name: selectedFile.fileName)
                attachment.size = Int(selectedFile.fileSize)
                print("size = \(Int(selectedFile.fileSize))")
                switch selectedFile.sourceType {
                case .image, .phAsset:
                    selectedFile.loadOriginalImage(completion: { (image) in
                        var scaledImage = image
                        
                        if (image?.size.width)! > CGFloat(2000.0) || (image?.size.height)! >= CGFloat(2000) {
                            scaledImage = IGUploadManager.compress(image: image!)
                        }
                        
                        attachment.attachedImage = scaledImage
                        let imgData = UIImageJPEGRepresentation(scaledImage!, 0.7)
                        let randomString = IGGlobal.randomString(length: 16) + "_"
                        let fileNameOnDisk = randomString + selectedFile.fileName!
                        attachment.fileNameOnDisk = fileNameOnDisk
                        self.saveAttachmentToLocalStorage(data: imgData!, fileNameOnDisk: fileNameOnDisk)
                        
                        attachment.height = Double((scaledImage?.size.height)!)
                        attachment.width = Double((scaledImage?.size.width)!)
                        attachment.size = (imgData?.count)!
                        attachment.data = imgData
                        attachment.type = .image
                        
                        self.inputBarAttachmentViewThumnailImageView.image = attachment.attachedImage
                        
                        self.inputBarAttachmentViewThumnailImageView.layer.cornerRadius = 6.0
                        self.inputBarAttachmentViewThumnailImageView.layer.masksToBounds = true
                        
                        self.didSelectAttachment(attachment)
                    })
                    break
                case .documentURL:
                    //recorded videos will be here
                    //also selected files form other apps
                    
                    if selectedFile.originalFileResource() is String {
                        print ("This is a file selected from ")
                        let selectedFilePath = selectedFile.originalFileResource() as! String
                        
                        
                        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                        let randomString = IGGlobal.randomString(length: 16) + "_"
                        attachment.fileNameOnDisk = randomString + selectedFile.fileName!
                        let pathOnDisk = documents + "/" + randomString + selectedFile.fileName!
                        
                        try! FileManager.default.copyItem(atPath: selectedFilePath, toPath: pathOnDisk)
                        attachment.height = 0
                        print(URL(string: pathOnDisk)!.pathExtension)
                        attachment.width = 0
                        switch URL(string: pathOnDisk)!.pathExtension {
                        case "MP3":
                            attachment.type = .audio
                        case "MOV":
                            attachment.type = .video
                        case "MP4":
                            attachment.type = .video
                        default:
                            attachment.type = .file
                        }
                        attachment.name = selectedFile.fileName
                        
                        self.inputBarAttachmentViewThumnailImageView.layer.cornerRadius = 6.0
                        self.inputBarAttachmentViewThumnailImageView.layer.masksToBounds = true
                        
                        self.didSelectAttachment(attachment)
                    }
                    
                    
                    break
                case .unknown:
                    break
                }
            }
        }, cancel: nil)

        
        attachmentPickerController.mediaType = [.image , .video]
        attachmentPickerController.capturedVideoQulity = .typeHigh
        attachmentPickerController.allowsMultipleSelection = false
        attachmentPickerController.allowsSelectionFromOtherApps = true
        attachmentPickerController.present(on: self)
    }
    
    @IBAction func didTapOnDeleteSelectedAttachment(_ sender: UIButton) {
        self.currentAttachment = nil
        self.setInputBarHeight()
        let text = inputTextView.text as NSString
        if text.length > 0 {
            self.inputBarSendButton.isHidden = false
            self.inputBarRecordButton.isHidden = true
        } else {
            self.inputBarSendButton.isHidden = true
            self.inputBarRecordButton.isHidden = false
        }
    }
    
    @IBAction func didTapOnCancelReplyOrForwardButton(_ sender: UIButton) {
        self.selectedMessageToForwardToThisRoom = nil
        self.selectedMessageToReply = nil
        self.setInputBarHeight()
        self.setSendAndRecordButtonStates()
    }
    
    @IBAction func didTapOnScrollToBottomButton(_ sender: UIButton) {
        self.collectionView.setContentOffset(CGPoint(x: 0, y: -self.collectionView.contentInset.top) , animated: false)
    }
    
    @IBAction func didTapOnJoinButton(_ sender: UIButton) {
        var username: String?
        if room?.channelRoom != nil {
            if let channelRoom = room?.channelRoom {
                if channelRoom.type == .publicRoom {
                    username = channelRoom.publicExtra?.username
                }
            }
        }
        if room?.groupRoom != nil {
            if let groupRoom = room?.groupRoom {
                if groupRoom.type == .publicRoom {
                    username = groupRoom.publicExtra?.username
                }
            }
        }
        if let publicRooomUserName = username {
            self.hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            self.hud.mode = .indeterminate
            IGClientJoinByUsernameRequest.Generator.generate(userName: publicRooomUserName).success({ (protoResponse) in
                DispatchQueue.main.async {
                    switch protoResponse {
                    case let clientJoinbyUsernameResponse as IGPClientJoinByUsernameResponse:
                        IGClientJoinByUsernameRequest.Handler.interpret(response: clientJoinbyUsernameResponse)
                        self.joinButton.isHidden = true
                        self.hud.hide(animated: true)
                        self.collectionViewTopInsetOffset = -54.0 + 8.0
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
                case .clinetJoinByUsernameForbidden:
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Error", message: "You don't have permission to join this room", preferredStyle: .alert)
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
    

    //MARK: AudioRecorder
    func didTapAndHoldOnRecord(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            startRecording()
            initialLongTapOnRecordButtonPosition = gestureRecognizer.location(in: self.view)
        case .cancelled:
            print("cancelled")
        case .changed:
            let point = gestureRecognizer.location(in: self.view)
            let difX = (initialLongTapOnRecordButtonPosition?.x)! - point.x
            
            var newConstant:CGFloat = 0.0
            if difX > 10 {
                newConstant = 74 - difX
            } else {
                newConstant = 74
            }
            
            if newConstant > 0{
                inputBarRecordViewLeftConstraint.constant = newConstant
                UIView.animate(withDuration: 0.1, animations: {
                    self.view.layoutIfNeeded()
                })
            } else {
                cancelRecording()
            }
            
            print("point: \(difX)")
            print("constant: \(inputBarRecordViewLeftConstraint.constant)")
            
        case .ended:
            finishRecording()
        case .failed:
            print("failed")
        case .possible:
            print("possible")
        }
    }
    
    func startRecording() {
        prepareViewForRecord()
        recordVoice()
    }
    
    func cancelRecording() {
        cleanViewAfterRecord()
        recorder?.stop()
        isRecordingVoice = false
        voiceRecorderTimer?.invalidate()
        recordedTime = 0
    }
    
    func finishRecording() {
        cleanViewAfterRecord()
        recorder?.stop()
        voiceRecorderTimer?.invalidate()
        recordedTime = 0
    }
    
    func prepareViewForRecord() {
        //disable rotation
        self.isRecordingVoice = true
        
        inputBarRecordView.isHidden = false
        inputBarRecodingBlinkingView.isHidden = false
        inputBarRecordRightView.isHidden = false
        inputBarRecordTimeLabel.isHidden = false
        
        inputTextView.isHidden = true
        inputBarLeftView.isHidden = true
        
        inputBarRecordViewLeftConstraint.constant = 74
        UIView.animate(withDuration: 0.5) {
            self.inputBarRecordTimeLabel.alpha = 1.0
            self.view.layoutIfNeeded()
        }
        
        if bouncingViewWhileRecord != nil {
            bouncingViewWhileRecord?.removeFromSuperview()
        }
        
        let frame = self.inputBarView.convert(inputBarRecordRightView.frame, from: inputBarRecordRightView)
        let width = frame.size.width
        //let bouncingViewFrame = CGRect(x: frame.origin.x - 2*width, y: frame.origin.y - 2*width, width: 3*width, height: 3*width)
        let bouncingViewFrame = CGRect(x: 0, y: 0, width: 3*width, height: 3*width)
        bouncingViewWhileRecord = UIView(frame: bouncingViewFrame)
        bouncingViewWhileRecord?.layer.cornerRadius = width * 3/2
        bouncingViewWhileRecord?.backgroundColor = UIColor.organizationalColor()
        bouncingViewWhileRecord?.alpha = 0.2
        self.view.addSubview(bouncingViewWhileRecord!)
        bouncingViewWhileRecord?.snp.makeConstraints { (make) -> Void in
            make.width.height.equalTo(3*width)
            make.center.equalTo(self.inputBarRecordRightView)
        }
        
        
        let alpha = POPBasicAnimation(propertyNamed: kPOPViewAlpha)
        alpha?.toValue = 0.0
        alpha?.repeatForever = true
        alpha?.autoreverses = true
        alpha?.duration = 1.0
        inputBarRecodingBlinkingView.pop_add(alpha, forKey: "alphaBlinking")
        
        let size = POPSpringAnimation(propertyNamed: kPOPViewScaleXY)
        size?.toValue = NSValue(cgPoint: CGPoint(x: 0.8, y: 0.8))
        size?.velocity = NSValue(cgPoint: CGPoint(x: 2, y: 2))
        size?.springBounciness = 20.0
        size?.repeatForever = true
        size?.autoreverses = true
        bouncingViewWhileRecord?.pop_add(size, forKey: "size")
        
        
        voiceRecorderTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimerLabel), userInfo: nil, repeats: true)
        voiceRecorderTimer?.fire()
    }
    
    func cleanViewAfterRecord() {
        inputBarRecordViewLeftConstraint.constant = 200
        UIView.animate(withDuration: 0.5) {
            self.inputBarRecordTimeLabel.text = "00:00"
            self.inputBarRecordTimeLabel.alpha = 0.0
            self.view.layoutIfNeeded()
        }
        
        
        UIView.animate(withDuration: 0.3, animations: {
            self.inputBarRecordView.alpha = 0.0
            self.inputBarRecodingBlinkingView.alpha = 0.0
            self.inputBarRecordRightView.alpha = 0.0
            self.inputBarRecordTimeLabel.alpha = 0.0
        }, completion: { (success) -> Void in
            //TODO: enable rotation
            self.inputBarRecordView.isHidden = true
            self.inputBarRecodingBlinkingView.isHidden = true
            self.inputBarRecordRightView.isHidden = true
            self.inputBarRecordTimeLabel.isHidden = true
            
            self.inputBarRecordView.alpha = 1.0
            self.inputBarRecodingBlinkingView.alpha = 1.0
            self.inputBarRecordRightView.alpha = 1.0
            self.inputBarRecordTimeLabel.alpha = 1.0
            
            self.inputTextView.isHidden = false
            self.inputBarLeftView.isHidden = false
            
            //animation
            self.inputBarRecodingBlinkingView.pop_removeAllAnimations()
            self.inputBarRecodingBlinkingView.alpha = 1.0
            self.bouncingViewWhileRecord?.removeFromSuperview()
            self.bouncingViewWhileRecord = nil
        })
        
        
    }
    
    func updateTimerLabel() {
        recordedTime += 1
        let minute = String(format: "%02d", Int(recordedTime/60))
        let seconds = String(format: "%02d", Int(recordedTime%60))
        inputBarRecordTimeLabel.text = minute + ":" + seconds
    }
    
    func recordVoice() {
        do {
            self.sendRecordingVoice()
            let fileName = "Recording - \(NSDate.timeIntervalSinceReferenceDate)"
            
            let writePath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)?.appendingPathExtension("m4a")
            
            var audioRecorderSetting = Dictionary<String, Any>()
            audioRecorderSetting[AVFormatIDKey] = NSNumber(value: kAudioFormatMPEG4AAC)
            audioRecorderSetting[AVSampleRateKey] = NSNumber(value: 44100.0)
            audioRecorderSetting[AVNumberOfChannelsKey] = NSNumber(value: 2)
            
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            
            recorder = try AVAudioRecorder(url: writePath!, settings: audioRecorderSetting)
            if recorder == nil {
                didFinishRecording(success: false)
                return
            }
            recorder?.isMeteringEnabled = true
            recorder?.delegate = self
            recorder?.prepareToRecord()
            recorder?.record()
        } catch {
            didFinishRecording(success: false)
        }
    }
    
    func didFinishRecording(success: Bool) {
        print((recorder?.url)!)
        recorder = nil
    }
    
    //MARK: Attachment Handlers
    func didSelectAttachment(_ attachment: IGFile) {
        self.currentAttachment = attachment
        self.setInputBarHeight()
        self.inputBarSendButton.isHidden = false
        self.inputBarRecordButton.isHidden = true
        self.inputBarAttachmentViewFileNameLabel.text  = currentAttachment?.name
        let sizeInByte = currentAttachment!.size
        var sizeSting = ""
        if sizeInByte < 1024 {
            //byte
            sizeSting = "\(sizeInByte) B"
        } else if sizeInByte < 1048576 {
            //kilobytes
            sizeSting = "\(sizeInByte/1024) KB"
        } else if sizeInByte < 1073741824 {
            //megabytes
            sizeSting = "\(sizeInByte/1048576) MB"
        } else { //if sizeInByte < 1099511627776 {
            //gigabytes
            sizeSting = "\(sizeInByte/1073741824) GB"
        }
        self.inputBarAttachmentViewFileSizeLabel.text = sizeSting
    }

    func saveAttachmentToLocalStorage(data: Data, fileNameOnDisk: String) {
        let path = IGFile.path(fileNameOnDisk: fileNameOnDisk)
        FileManager.default.createFile(atPath: path.path, contents: data, attributes: nil)
    }
    
    //MARK: Actions for tap and hold on messages
    fileprivate func copyMessage(_ message: IGRoomMessage) {
        if let text = message.message {
            UIPasteboard.general.string = text
        }
    }
    
    fileprivate func editMessage(_ message: IGRoomMessage) {
        self.selectedMessageToEdit = message
        self.selectedMessageToReply = nil
        self.selectedMessageToForwardToThisRoom = nil
        
        self.inputTextView.text = message.message
        inputTextView.placeHolder = "Write here ..."
        self.inputTextView.becomeFirstResponder()
        self.inputBarOriginalMessageViewSenderNameLabel.text = "Edit Message"
        self.inputBarOriginalMessageViewBodyTextLabel.text = message.message
        self.setInputBarHeight()
        
    }
    
    fileprivate func replyMessage(_ message: IGRoomMessage) {
        self.selectedMessageToEdit = nil
        self.selectedMessageToReply = message
        self.selectedMessageToForwardToThisRoom = nil
        self.inputBarOriginalMessageViewSenderNameLabel.text = message.authorUser?.displayName
        self.inputBarOriginalMessageViewBodyTextLabel.text = message.message
        self.setInputBarHeight()
    }
    
    fileprivate func forwardMessage(_ message: IGRoomMessage) {
        self.selectedMessageToEdit = nil
        self.selectedMessageToReply = nil
        self.selectedMessageToForwardFromThisRoom = message
        self.inputBarOriginalMessageViewSenderNameLabel.text = message.authorUser?.displayName
        self.inputBarOriginalMessageViewBodyTextLabel.text = message.message
        self.setInputBarHeight()
        self.setSendAndRecordButtonStates()
    }
    
    
    fileprivate func deleteMessage(_ message: IGRoomMessage) {
        switch room!.type {
        case .chat:
            IGChatDeleteMessageRequest.Generator.generate(message: message, room: self.room!).success { (responseProto) in
                switch responseProto {
                case let response as IGPChatDeleteMessageResponse:
                    IGChatDeleteMessageRequest.Handler.interpret(response: response)
                default:
                    break
                }
            }.error({ (errorCode, waitTime) in
                
            }).send()
        case .group:
            IGGroupDeleteMessageRequest.Generator.generate(message: message, room: room!).success({ (responseProto) in
                switch responseProto {
                case let response as IGPGroupDeleteMessageResponse:
                    IGGroupDeleteMessageRequest.Handler.interpret(response: response)
                default:
                    break
                }
            }).error({ (errorCode, waitTime) in
                
            }).send()
        case .channel:
            IGChannelDeleteMessageRequest.Generator.generate(message: message, room: room!).success({ (responseProto) in
                switch responseProto {
                case let response as IGPChannelDeleteMessageResponse:
                    IGChannelDeleteMessageRequest.Handler.interpret(response: response)
                default:
                    break
                }
            }).error({ (errorCode, waitTime) in
                
            }).send()
        }
    }
    
    
    //MARK: UI states
    func setSendAndRecordButtonStates() {
        if self.selectedMessageToForwardToThisRoom != nil {
            inputBarSendButton.isHidden = false
            inputBarRecordButton.isHidden = true
        } else {
            let text = self.inputTextView.text as NSString
            if text.length == 0 && currentAttachment == nil {
                //empty -> show recored
                inputBarSendButton.isHidden = true
                inputBarRecordButton.isHidden = false
            } else {
                //show send
                inputBarSendButton.isHidden = false
                inputBarRecordButton.isHidden = true
            }
        }
    }
    
    //MARK: Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showUserInfo" {
            let destinationVC = segue.destination as! IGRegistredUserInfoTableViewController
            destinationVC.user = self.selectedUserToSeeTheirInfo
            destinationVC.previousRoomId = room?.id
            destinationVC.room = room
        }
        if segue.identifier == "showChannelinfo" {
            let destinationVC = segue.destination as! IGChannelInfoTableViewController
            destinationVC.selectedChannel = selectedChannelToSeeTheirInfo
            destinationVC.room = room
        }
        if segue.identifier == "showGroupInfo" {
            let destinationTv = segue.destination as! IGGroupInfoTableViewController
            destinationTv.selectedGroup = selectedGroupToSeeTheirInfo
            destinationTv.room = room
        }
        if segue.identifier == "showForwardMessageTable" {
            let navigationController = segue.destination as! IGNavigationController
            let destinationTv = navigationController.topViewController as! IGForwardMessageTableViewController
            destinationTv.delegate = self
        }
    }
 
}

////MARK: - UICollectionView
//extension UICollectionView {
//    func applyChangeset(_ changes: RealmChangeset) {
//        performBatchUpdates({
//            self.insertItems(at: changes.inserted.map { IndexPath(row: 0, section: $0) })
//            self.deleteItems(at: changes.updated.map { IndexPath(row: 0, section: $0) })
//            self.reloadItems(at: changes.deleted.map { IndexPath(row: 0, section: $0) })
//        }, completion: { (completed) in
//            
//        })
//    }
//}


//MARK: - IGMessageCollectionViewDataSource
extension IGMessageViewController: IGMessageCollectionViewDataSource {
    func collectionView(_ collectionView: IGMessageCollectionView, messageAt indexpath: IndexPath) -> IGRoomMessage {
        return messages![indexpath.section]
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if messages != nil {
            return messages!.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let message = messages![indexPath.section]
        
        if message.type == .log {
            let cell: IGMessageLogCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: logMessageCellIdentifer, for: indexPath) as! IGMessageLogCollectionViewCell
            let bubbleSize = IGMessageCollectionViewCellSizeCalculator.sharedCalculator.mainBubbleCountainerSize(for: message)
            cell.setMessage(message,
                            isIncommingMessage: true,
                            shouldShowAvatar: false,
                            messageSizes:bubbleSize,
                            isPreviousMessageFromSameSender: false,
                            isNextMessageFromSameSender: false)
            return cell
        } else{
            
        
        
            let cell: IGMessageCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: messageCellIdentifer, for: indexPath) as! IGMessageCollectionViewCell
            
            var isIncommingMessage = true
            if let senderHash = message.authorHash {
                if senderHash == IGAppManager.sharedManager.authorHash() {
                    isIncommingMessage = false
                }
            }
            
            
            var shouldShowAvatar = false
            if room?.groupRoom != nil {
                shouldShowAvatar = true
            }
            if !isIncommingMessage {
                shouldShowAvatar = false
            }
            
            
            var isPreviousMessageFromSameSender = false
            var isNextMessageFromSameSender = false
            

            if messages!.indices.contains(indexPath.section + 1){
                let previousMessage = messages![(indexPath.section + 1)]
                if previousMessage.type != .log && message.authorHash == previousMessage.authorHash {
                    isPreviousMessageFromSameSender = true
                }
            }
            
            if messages!.indices.contains(indexPath.section - 1){
                let nextMessage = messages![(indexPath.section - 1)]
                if message.authorHash == nextMessage.authorHash {
                    isNextMessageFromSameSender = true
                }
            }
        
            let bubbleSize = IGMessageCollectionViewCellSizeCalculator.sharedCalculator.mainBubbleCountainerSize(for: message)
            cell.setMessage(message,
                            isIncommingMessage: isIncommingMessage,
                            shouldShowAvatar: shouldShowAvatar,
                            messageSizes:bubbleSize,
                            isPreviousMessageFromSameSender: isPreviousMessageFromSameSender,
                            isNextMessageFromSameSender: isNextMessageFromSameSender)
            cell.delegate = self
            return cell
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        var shouldShowFooter = false
        
        if let message = messages?[section] {
            if message.shouldFetchBefore {
                shouldShowFooter = true
            } else if section < messages!.count - 1, let previousMessage =  messages?[section + 1] {
                let thisMessageDateComponents     = Calendar.current.dateComponents([.year, .month, .day], from: message.creationTime!)
                let previousMessageDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: previousMessage.creationTime!)
                
                if thisMessageDateComponents.year == previousMessageDateComponents.year &&
                    thisMessageDateComponents.month == previousMessageDateComponents.month &&
                    thisMessageDateComponents.day == previousMessageDateComponents.day
                {
                    
                } else {
                    shouldShowFooter = true
                }
            } else {
                //first message in room -> always show time
                shouldShowFooter = true
            }
        }
        
        if shouldShowFooter {
            return CGSize(width: 35, height: 30.0)
        } else {
            return CGSize(width: 0.001, height: 0.001)//CGSize.zero
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        var reusableview = UICollectionReusableView()
        if kind == UICollectionElementKindSectionFooter {
            
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionFooter, withReuseIdentifier: IGMessageLogCollectionViewCell.cellReuseIdentifier(), for: indexPath) as! IGMessageLogCollectionViewCell
            
            if let message = messages?[indexPath.section] {
                if message.shouldFetchBefore {
                    header.setText("Loading ...")
                } else {
                    
                    let dayTimePeriodFormatter = DateFormatter()
                    dayTimePeriodFormatter.dateFormat = "MMMM dd"
                    dayTimePeriodFormatter.calendar = Calendar.current
                    let dateString = dayTimePeriodFormatter.string(from: message.creationTime!)
                    header.setText(dateString)
                }
            }
            reusableview = header
        }
        return reusableview
    }
}

//MARK: - UICollectionViewDelegateFlowLayout
extension IGMessageViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let message = messages![indexPath.section]
        var frame = self.collectionView.layout.size(for: message).bubbleSize
        
        var isPreviousMessageFromSameSender = false
        
        if messages!.indices.contains(indexPath.section + 1){
            let previousMessage = messages![(indexPath.section + 1)]
            if previousMessage.type != .log && message.authorHash == previousMessage.authorHash {
                isPreviousMessageFromSameSender = true
            }
        }

        if isPreviousMessageFromSameSender || message.type == .log {
            frame.height -= 7.5
        }
        
        return CGSize(width: self.collectionView.frame.width, height: frame.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(0, 0, 0, 0)
    }

    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.inputTextView.resignFirstResponder()
    }
    
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let message = messages![indexPath.section]
        if message.shouldFetchBefore {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.fetchRoomHistoryIfPossibleBefore(message: message)
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let spaceToTop = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.height
        //500 is an arbitrary number. can be anything
        if spaceToTop < 500 {
            //near top of the screen (real bottom of scrollview)
            let predicate = NSPredicate(format: "roomId = %d", self.room!.id)
            if let message = try! Realm().objects(IGRoomMessage.self).filter(predicate).sorted(by: sortProperties).last {
                self.fetchRoomHistoryIfPossibleBefore(message: message)
            }
        }
        //100 is an arbitrary number. can be anything
        if scrollView.contentOffset.y > 100 {
            self.scrollToBottomContainerView.isHidden = false
        } else {
            self.scrollToBottomContainerView.isHidden = true
        }
    }
    
    private func fetchRoomHistoryIfPossibleBefore(message: IGRoomMessage) {
        if !message.isLastMessage {
            if !isFetchingRoomHistory {
                isFetchingRoomHistory = true
                
                IGClientGetRoomHistoryRequest.Generator.generate(roomID: self.room!.id, firstMessageID: message.id).success({ (responseProto) in
                    //TODO: no longer needs to fetch -> message.shouldFetchBefore = false
                    self.isFetchingRoomHistory = false
                    DispatchQueue.main.async {
                        IGFactory.shared.setMessageNeedsToFetchBefore(false, messageId: message.id, roomId: message.roomId)
                        switch responseProto {
                        case let roomHistoryReponse as IGPClientGetRoomHistoryResponse:
                            IGClientGetRoomHistoryRequest.Handler.interpret(response: roomHistoryReponse, roomId: self.room!.id)
                        default:
                            break
                        }
                    }
                }).error({ (errorCode, waitTime) in
                    DispatchQueue.main.async {
                        switch errorCode {
                        case .clinetGetRoomHistoryNoMoreMessage:
                            IGFactory.shared.setMessageIsLastMesssageInRoom(messageId: message.id, roomId: message.roomId)
                            break
                        case .timeout:
                            break
                        default:
                            break
                        }
                    }
                    self.isFetchingRoomHistory = false
                }).send()
            }
        }   
    }
}


//MARK: - GrowingTextViewDelegate
extension IGMessageViewController: GrowingTextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        self.setSendAndRecordButtonStates()
        self.sendTyping()
        typingStatusExpiryTimer.invalidate()
        typingStatusExpiryTimer = Timer.scheduledTimer(timeInterval: 1.0,
                                                       target:   self,
                                                       selector: #selector(sendCancelTyping),
                                                       userInfo: nil,
                                                       repeats:  false)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
//        self.sendTyping()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        self.sendCancelTyping()
    }
    
    func textViewDidChangeHeight(_ height: CGFloat) {
        inputTextViewHeight = height
        setInputBarHeight()
    }
    
    
    func setInputBarHeight() {
        let height = max(self.inputTextViewHeight - 16, 22)
        var inputBarHeight = height + 16.0
        if currentAttachment != nil {
            inputBarAttachmentViewBottomConstraint.constant = inputBarHeight + 8
            inputBarHeight += 36
            inputBarAttachmentView.isHidden = false
        } else {
            inputBarAttachmentViewBottomConstraint.constant = 0.0
            inputBarAttachmentView.isHidden = true
        }
        
        if selectedMessageToEdit != nil {
            inputBarOriginalMessageViewBottomConstraint.constant = inputBarHeight + 8
            inputBarHeight += 36.0
            inputBarOriginalMessageView.isHidden = false
        } else if selectedMessageToReply != nil {
            inputBarOriginalMessageViewBottomConstraint.constant = inputBarHeight + 8
            inputBarHeight += 36.0
            inputBarOriginalMessageView.isHidden = false
        } else if selectedMessageToForwardToThisRoom != nil {
            inputBarOriginalMessageViewBottomConstraint.constant = inputBarHeight + 8
            inputBarHeight += 36.0
            inputBarOriginalMessageView.isHidden = false
        } else {
            inputBarOriginalMessageViewBottomConstraint.constant = 0.0
            inputBarOriginalMessageView.isHidden = true
        }
        
        inputTextViewHeightConstraint.constant = height
        inputBarHeightConstraint.constant = inputBarHeight
        inputBarHeightContainerConstraint.constant = inputBarHeight + 16
//        UIView.animate(withDuration: 0.2) {
//            self.view.layoutIfNeeded()
//        }
        
        UIView.animate(withDuration: 0.2, animations: { 
            self.view.layoutIfNeeded()
        }, completion: { (completed) in
            self.setCollectionViewInset()
        })
    }
}

//MARK: - AVAudioRecorderDelegate
extension IGMessageViewController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        sendCancelRecoringVoice()
        if self.isRecordingVoice {
            self.didFinishRecording(success: flag)
            let filePath = recorder.url
            //discard file if time is too small
            
            //AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:avAudioRecorder.url options:nil];
            //CMTime time = asset.duration;
            //double durationInSeconds = CMTimeGetSeconds(time);
            let asset = AVURLAsset(url: filePath)
            let time = CMTimeGetSeconds(asset.duration)
            if time < 1.0 {
                return
            }
            do {
                let attachment = IGFile(name: filePath.lastPathComponent)
                
                let data = try Data(contentsOf: filePath)
                self.saveAttachmentToLocalStorage(data: data, fileNameOnDisk: filePath.lastPathComponent)
                attachment.fileNameOnDisk = filePath.lastPathComponent
                attachment.size = data.count
                attachment.type = .voice
                self.currentAttachment = attachment
                self.didTapOnSendButton(self.inputBarSendButton)
            } catch {
                //there was an error recording voice
            }
        }
        self.isRecordingVoice = false
    }
}

//MARK: - IGMessageGeneralCollectionViewCellDelegate
extension IGMessageViewController: IGMessageGeneralCollectionViewCellDelegate {
    func didTapAndHoldOnMessage(cellMessage: IGRoomMessage, cell: IGMessageGeneralCollectionViewCell) {
        print(#function)
        let alertC = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let copy = UIAlertAction(title: "Copy", style: .default, handler: { (action) in
            self.copyMessage(cellMessage)
        })
        let reply = UIAlertAction(title: "Reply", style: .default, handler: { (action) in
            self.replyMessage(cellMessage)
        })
        let forward = UIAlertAction(title: "Forward", style: .default, handler: { (action) in
            self.selectedMessageToForwardFromThisRoom = cellMessage
            self.performSegue(withIdentifier: "showForwardMessageTable", sender: self)
        })
        let edit = UIAlertAction(title: "Edit", style: .default, handler: { (action) in
            self.editMessage(cellMessage)
        })
        let more = UIAlertAction(title: "More", style: .default, handler: { (action) in
            for visibleCell in self.collectionView.visibleCells {
                let aCell = visibleCell as! IGMessageGeneralCollectionViewCell
                aCell.setMultipleSelectionMode(true)
            }
        })
        let delete = UIAlertAction(title: "Delete", style: .destructive, handler: { (action) in
            self.deleteMessage(cellMessage)
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
        })
        
        //Copy
        alertC.addAction(copy)
        
        //Reply
        if !(room!.isReadOnly){
            alertC.addAction(reply)
        }
        
        //Forward
        alertC.addAction(forward)
        
        //Edit
        if cellMessage.authorHash == currentLoggedInUserAuthorHash ||
            (self.room!.type == .channel && self.room!.channelRoom!.role == .owner) ||
            (self.room!.type == .group   && self.room!.groupRoom!.role   == .owner)
        {
            alertC.addAction(edit)
        }
        
        //More (Temporary Disabled)
        //alertC.addAction(more)
        
        
        //Delete
        if cellMessage.authorHash == currentLoggedInUserAuthorHash ||
            (self.room!.type == .channel && self.room!.channelRoom!.role == .owner) ||
            (self.room!.type == .group   && self.room!.groupRoom!.role   == .owner)
        {
            alertC.addAction(delete)
        }
        
        alertC.addAction(cancel)
        
        self.present(alertC, animated: true, completion: {
            
        })
    }
    
    func didTapOnAttachment(cellMessage: IGRoomMessage, cell: IGMessageGeneralCollectionViewCell) {
        //TODO: check forwarded attachment
        let message = cellMessage
        if message.attachment == nil {
            return
        }
        
        var attachmetVariableInCache = IGAttachmentManager.sharedManager.getRxVariable(attachmentPrimaryKeyId: message.attachment!.primaryKeyId!)
        
        if attachmetVariableInCache == nil {
            let attachmentRef = ThreadSafeReference(to: message.attachment!)
            IGAttachmentManager.sharedManager.add(attachmentRef: attachmentRef)
            attachmetVariableInCache = IGAttachmentManager.sharedManager.getRxVariable(attachmentPrimaryKeyId: message.attachment!.primaryKeyId!)
        }
        
        let attachment = attachmetVariableInCache!.value
        if attachment.status != .ready {
            return
        }
        
        switch message.type {
        case .image, .imageAndText:
            break
        case .video, .videoAndText:
            print(attachment.status)
            print(message.type)
            if let path = attachment.path() {
                let player = AVPlayer(url: path)
                let avController = AVPlayerViewController()
                avController.player = player
                player.play()
                present(avController, animated: true, completion: nil)
            }
        case .voice , .audio :
            let musicPlayer = IGMusicViewController()
            musicPlayer.attachment = message.attachment
            self.present(musicPlayer, animated: true, completion: {
            })
            return
        default:
            return
        }
        
        //        let messagesWithMediaCount = self.messagesWithMedia.count
        //        let messagesWithForwardedMediaCount = self.messagesWithForwardedMedia.count
        
        
        let thisMessageInSharedMediaResult = self.messagesWithMedia.filter("id == \(message.id)")
        for messsss in thisMessageInSharedMediaResult {
            print ("iddd: \(messsss.id)")
        }
        var indexOfThis = 0
        if let this = thisMessageInSharedMediaResult.first {
            indexOfThis = self.messagesWithMedia.index(of: this)!
            print ("found it: \(indexOfThis)")
        } else {
            print ("not found it")
        }
        
        var photos: [INSPhotoViewable] = Array(self.messagesWithMedia.map { (message) -> IGMedia in
            return IGMedia(message: message, forwardedMedia: false)
        })
        
        let currentPhoto = photos[indexOfThis]
        
        let galleryPreview = INSPhotosViewController(photos: photos, initialPhoto: currentPhoto, referenceView: nil)
        
        //        galleryPreview.referenceViewForPhotoWhenDismissingHandler = { [weak self] photo in
        //            if let index = photos.index(where: {$0 === photo}) {
        //                let indexPath = NSIndexPath(forItem: index, inSection: 0)
        //                return collectionView.cellForItemAtIndexPath(indexPath) as? ExampleCollectionViewCell
        //            }
        //            return nil
        //        }
        present(galleryPreview, animated: true, completion: nil)
    }
    
    func didTapOnForwardedAttachment(cellMessage: IGRoomMessage, cell: IGMessageGeneralCollectionViewCell) {
        if let forwardedMsgType = cellMessage.forwardedFrom?.type {
        switch forwardedMsgType {
        case .audio , .voice :
            let musicPlayer = IGMusicViewController()
            musicPlayer.attachment = cellMessage.forwardedFrom?.attachment
            self.present(musicPlayer, animated: true, completion: {
            })
            break
        case .video, .videoAndText:
            if let path = cellMessage.forwardedFrom?.attachment?.path() {
                let player = AVPlayer(url: path)
                let avController = AVPlayerViewController()
                avController.player = player
                player.play()
                present(avController, animated: true, completion: nil)
            }
        default:
            break
        }
        }
    }
    
    func didTapOnOriginalMessageWhenReply(cellMessage: IGRoomMessage, cell: IGMessageGeneralCollectionViewCell) {
        
    }
    
    func didTapOnSenderAvatar(cellMessage: IGRoomMessage, cell: IGMessageGeneralCollectionViewCell) {
        if let sender = cellMessage.authorUser {
            self.selectedUserToSeeTheirInfo = sender
            self.performSegue(withIdentifier: "showUserInfo", sender: self)
        }
    }
    
    func didTapOnHashtag(hashtagText: String) {
        
        
    }
    
    func didTapOnMention(mentionText: String) {
        self.hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        self.hud.mode = .indeterminate
        IGClientResolveUsernameRequest.Generator.generate(username: mentionText).success({ (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                case let clientResolvedUsernameResponse as IGPClientResolveUsernameResponse:
                    let clientResponse = IGClientResolveUsernameRequest.Handler.interpret(response: clientResolvedUsernameResponse)
                    
                    switch clientResponse.clientResolveUsernametype {
                    case .user:
                        self.selectedUserToSeeTheirInfo = clientResponse.user
                        self.performSegue(withIdentifier: "showUserInfo", sender: self)
                    case .room:
                        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
                        let messagesVc = storyBoard.instantiateViewController(withIdentifier: "messageViewController") as! IGMessageViewController
                        self.inputTextView.resignFirstResponder()
                        messagesVc.room = clientResponse.room
                        self.navigationController!.pushViewController(messagesVc, animated:false)

                        break
                    }
                default:
                    break
                }
                self.inputTextView.resignFirstResponder()
                self.hud.hide(animated: true)
            }
        }).error ({ (errorCode, waitTime) in
            switch errorCode {
            case .timeout:
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Timeout", message: "Please try again later", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    
                    self.present(alert, animated: true, completion: nil)
                }
            default:
                break
            }
            self.hud.hide(animated: true)
        }).send()
    }
    
    func didTapOnURl(url: URL) {
        var urlString = url.absoluteString.lowercased()
        if !(urlString.contains("https://")) && !(urlString.contains("http://")) {
            urlString = "http://" + urlString
        }
        if let urlToOpen = URL(string: urlString) {
            UIApplication.shared.openURL(urlToOpen)
        }
        //TODO: handle "igap.net/join"
    }
    func didTapOnRoomLink(link: String) {
       let sth =  link.chopPrefix(14)
        print(sth)
        let alert = UIAlertController(title: "iGap", message: "Are you sure want to join this room?", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: { (action) in
            self.joinRoombyInvitedLink(invitedToken: sth)
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alert.addAction(okAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)

    }
    
    func joinRoombyInvitedLink(invitedToken: String) {
        self.hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        self.hud.mode = .indeterminate
        IGClientJoinByInviteLinkRequest.Generator.generate(invitedToken: invitedToken).success({ (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                case let clinetJoinByInvitedlink as IGPClientJoinByInviteLinkResponse:
                   let response = IGClientJoinByInviteLinkRequest.Handler.interpret(response: clinetJoinByInvitedlink)
                    print(response)
                   //self.requestToCheckInvitedLink(invitedLink: invitedToken)
                    self.hud.hide(animated: true)
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
                    
                    self.present(alert, animated: true, completion: nil)
                }
            case .clientJoinByInviteLinkForbidden:
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error", message: "Sorry,this group does not seem to exist.", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    self.hud.hide(animated: true)
                    self.present(alert, animated: true, completion: nil)
                }
            case .clientJoinByInviteLinkAlreadyJoined:
                DispatchQueue.main.async {
                    self.requestToCheckInvitedLink(invitedLink: invitedToken)
                }

            default:
                break
            }
            self.hud.hide(animated: true)
            
        }).send()

    }
    func requestToCheckInvitedLink(invitedLink: String) {
        IGClinetCheckInviteLinkRequest.Generator.generate(invitedToken: invitedLink).success({ (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                    case let clinetcheckInvitedlink as IGPClientCheckInviteLinkResponse:
                        let room = IGClinetCheckInviteLinkRequest.Handler.interpret(response: clinetcheckInvitedlink)
                        print(room)
                        
                        self.hud.hide(animated: true)
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kIGNotificationNameDidCreateARoom),
                                                            object: nil,
                                                            userInfo: ["room": room.id])
                            

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
                    
                    self.present(alert, animated: true, completion: nil)
                }
                
            default:
                break
            }
            self.hud.hide(animated: true)
            
        }).send()
    }

}

//MARK: - IGForwardMessageDelegate
extension IGMessageViewController : IGForwardMessageDelegate {
    func didSelectRoomToForwardMessage(room: IGRoom) {
        if room.id == self.room?.id {
            self.forwardMessage(self.selectedMessageToForwardFromThisRoom!)
            return
        }
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let messagesVc = storyBoard.instantiateViewController(withIdentifier: "messageViewController") as! IGMessageViewController
        self.inputTextView.resignFirstResponder()
        messagesVc.room = room
        messagesVc.selectedMessageToForwardToThisRoom = self.selectedMessageToForwardFromThisRoom
        self.selectedMessageToForwardFromThisRoom = nil
        self.navigationController!.pushViewController(messagesVc, animated:false)
    }
}



//MARK: - StatusBar Tap
extension IGMessageViewController {
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        return false
    }
    
    func addNotificationObserverForTapOnStatusBar() {
        NotificationCenter.default.addObserver(forName: statusBarTappedNotification.name, object: .none, queue: .none) { _ in
            if self.collectionView.contentSize.height < self.collectionView.frame.height {
                return
            }
            //1200 is just an arbitrary number. can be anything
            let newOffsetY = min(self.collectionView.contentOffset.y + 1200, self.collectionView.contentSize.height - self.collectionView.frame.height + self.collectionView.contentInset.bottom)
            let newOffsett = CGPoint(x: 0, y: newOffsetY)
            self.collectionView.setContentOffset(newOffsett , animated: true)
        }
    }    
}

//MARK: - Set and cancel current action (typing, ...)
extension IGMessageViewController {
    fileprivate func sendTyping() {
        IGClientActionManager.shared.sendTyping(for: self.room!)
    }
    @objc fileprivate func sendCancelTyping() {
        typingStatusExpiryTimer.invalidate()
        IGClientActionManager.shared.cancelTying(for: self.room!)
    }
    
    fileprivate func sendRecordingVoice() {
        IGClientActionManager.shared.sendRecordingVoice(for: self.room!)
    }
    fileprivate func sendCancelRecoringVoice() {
        IGClientActionManager.shared.sendCancelRecoringVoice(for: self.room!)
    }
    
//    Capturing Image
//    Capturign Video
//    Sending Gif
//    Sending Location
//    Choosing Contact
//    Painting
    
}
extension String {
    func chopPrefix(_ count: Int = 1) -> String {
        return substring(from: index(startIndex, offsetBy: count))
    }
    
    func chopSuffix(_ count: Int = 1) -> String {
        return substring(to: index(endIndex, offsetBy: -count))
    }
}
