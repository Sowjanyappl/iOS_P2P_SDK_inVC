//
//  SingleTonSocket.swift
//  InVC_iOS_SDK
//
//  Created by Sowjanya on 22/06/22.
//

import Foundation
//
//  SingleTon.swift
//  SampleSDKintegration
//
//  Created by Sowjanya on 22/06/22.
//

import Foundation
import NWWebSocket
import Network
import WebRTC
@objc public protocol SocketDelegates: AnyObject {
    @objc optional  func socketConnected(isConnected: Bool)
    @objc optional  func sendLocalVideoTrack(localVideoTrack:RTCVideoTrack)
    @objc optional  func sendRemoteVideoTrack(remoteVideoTrack:RTCVideoTrack)

    
    
    @objc optional func startIncomingCall(dict:[String:Any])
    @objc optional func declineIncomingCall(dict:[String:Any])
    @objc optional func acceptIncomingCall(dict:[String:Any])
    @objc optional func endVCCall(dict:[String:Any])

    
    @objc optional func sendOffer(dict:[String:Any])

    
    @objc optional func messageRecived(dict:[String:Any])

    
    

}

public class SingleTonSocket {
   public static let shared = SingleTonSocket()
    var mySocket : NWWebSocket!
    public weak var socketDelegate: SocketDelegates?
    var myUserId : String?
    typealias JSONDictionary = [String : Any]

    
    
    var videoClient: RTCClient?
    public var isReceiver = false
    public var isAudioCall = false

    public var remoteId: String?
    var sdpType = ""
    let iceServers = ["stun:stun.instavc.com:19302","turn:awsturn.instavc.com:443?transport=udp","turn:coturn:443?transport=tcp"]
    var captureController: RTCCapturer!

    //Initializer access level change now
    private init() { }
    
    public func connectMySocket(selfID:String) {
        myUserId = selfID
        guard let socketURL = URL(string: "wss://p2papi.instavc.com") else { return }
        mySocket = NWWebSocket(url: socketURL)
        mySocket.delegate = self
        mySocket.connect()
    }
    
    func stringToJsonObject(str: String) -> [String: Any]?{
        var dict:[String: Any]? = nil
        if let data = str.data(using: String.Encoding.utf8) {
            do {
                dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any]
            } catch let error as NSError {
                print(error)
            }
        }
        return dict
    }
    func jsonObjectToString(jsonDictionary: JSONDictionary) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonDictionary, options: .prettyPrinted)
            return String(data: data, encoding: String.Encoding.utf8) ?? ""
        } catch {
            return ""
        }
    }
    func connectToSocketServer() {
        guard let myId = myUserId else {return}
        let dict: JSONDictionary = ["type": "userid", "value": myId]
        sendSocketMessage(dict: dict)
    }
   public func sendSocketMessage(dict : [String:Any]){
        let dictAsString = jsonObjectToString(jsonDictionary: dict)
        mySocket.send(string: dictAsString)
    }
    
    public func configureVideoClient() {
        let client = RTCClient(iceServers: [RTCIceServer(urlStrings: iceServers, username: "admin", credential: "admin123")], videoCall: true)
        client.delegate = self
        
        self.videoClient = client
        client.startConnection()
        if !isReceiver {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let rid = self.remoteId {
                    let messageDict: JSONDictionary = ["type":"message","id":rid]
                    self.sendSocketMessage(dict: messageDict)
                }
                self.videoClient?.makeOffer()
                self.sdpType = "offer"
            }
        }
        
        
       
        
    }
    public func callIntiated(rid:String, isAudioCall:Bool){
        let dict: JSONDictionary = ["type": "call-initiated", "id": rid, "isAudioCall": isAudioCall]
        self.sendSocketMessage(dict: dict)
    }
    public func callDeclined(rid:String) {
        let dict: JSONDictionary = ["type": "call-declined", "id": rid]
        self.sendSocketMessage(dict: dict)

    }
    public func callAccepted(rid:String) {
        let dict: JSONDictionary = ["type": "call-accepted", "id": rid]
        self.sendSocketMessage(dict: dict)

    }
    public func createAnswerForOffer(sdpData:String) {
        self.sdpType = "answer"
        self.videoClient?.createAnswerForOfferReceived(withRemoteSDP:sdpData)
    }
    public func muteMicrophone(isMuted:Bool){
        self.videoClient?.muteCall(isMuted)

    }
    public func muteVideoCamera(isMuted:Bool) {
        self.videoClient?.muteVideoCall(isMuted)

    }
    public func switchCamera() {
        self.captureController.switchCamera()
    }
}

extension SingleTonSocket: RTCClientDelegate {
    public func rtcClient(client: RTCClient, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        print("myVideo1")
    }
    
    public func rtcClient(client: RTCClient, didGenerateIceCandidate iceCandidate: RTCIceCandidate) {
        let json: JSONDictionary = ["candidate": iceCandidate.sdp, "sdpMLineIndex" :iceCandidate.sdpMLineIndex, "sdpMid": iceCandidate.sdpMid!]
        guard let rid = remoteId else { return }
        DispatchQueue.main.async { [self] in
            let dict: JSONDictionary = ["type": "candidate", "candidate" :json, "id": rid]
            self.sendSocketMessage(dict: dict)

        }
    }
    public func rtcClient(client: RTCClient, didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack) {
        print("localVideoTrack,\(localVideoTrack)")
        if !isAudioCall {
           // localVideoTrack.add(localVideoView)
            socketDelegate?.sendLocalVideoTrack?(localVideoTrack: localVideoTrack)
        }
    }
    public func rtcClient(client: RTCClient, startCallWithSdp sdp: String) {
        print("SDP is,\(sdp)")
        guard let rid = remoteId else { return }
        
        DispatchQueue.main.async { [self] in
            let dict: JSONDictionary = ["type": self.sdpType, "sdp": sdp, "id":rid]
            self.sendSocketMessage(dict: dict)

        }
        
        
    }
    
    public func rtcClient(client: RTCClient, didCreateLocalCapturer capturer: RTCCameraVideoCapturer) {
        // To handle when camera is not available
        if UIDevice.current.model != "Simulator" && !isAudioCall {
            let settingModel = RTCCapturerSettingsModel()
            //print("settingModel \(settingModel.currentVideoCodecSettingFromStore())")
            self.captureController = RTCCapturer(withCapturer: capturer, settingsModel: settingModel)
            captureController.startCapture()
        }
    }
    public func rtcClient(client : RTCClient, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack) {
        // Use remoteVideoTrack generated for rendering stream to remoteVideoView
        if !isAudioCall {
            socketDelegate?.sendRemoteVideoTrack?(remoteVideoTrack: remoteVideoTrack)
        }
    }
    public func rtcClient(client : RTCClient, didReceiveError error: Error)
    {
        print("remoteVideoTrackError, \(error)")
        
    }
    
    public func rtcClient(client: RTCClient, didChangeState state: RTCClientState) {
        print("state is\(state)")
    }
}
extension SingleTonSocket : WebSocketConnectionDelegate {
    public func webSocketDidConnect(connection: WebSocketConnection) {
        print("socket connected")
        mySocket.ping(interval: 30.0)

    }
    public func webSocketDidDisconnect(connection: WebSocketConnection, closeCode: NWProtocolWebSocket.CloseCode, reason: Data?) {
        print("socket disconnected")
        
    }
    public func webSocketViabilityDidChange(connection: WebSocketConnection, isViable: Bool) {
        print("socket viabilityconnected")
        
    }
    public func webSocketDidAttemptBetterPathMigration(result: Result<WebSocketConnection, NWError>) {
        print("socket didattemptbetterpathmigration")
        
    }
    public func webSocketDidReceiveError(connection: WebSocketConnection, error: NWError) {
        print("socket error received", error)
       
    }
    public func webSocketDidReceivePong(connection: WebSocketConnection) {
        print("socket pong received")
    }
    public func webSocketDidReceiveMessage(connection: WebSocketConnection, string: String) {
        print("socket message received", string)
        if let text = string as? String {
            print("Recieved \(text)")
            
            // self.messageLabel.text = text
            if let dictionary = self.stringToJsonObject(str: text) {
                let type = dictionary["type"] as? String
                switch type {
                case "iceServers" :
                    print("ice servers coming")
                    connectToSocketServer()
                    break
                case "hello":
                    print("hello printed")
                    socketDelegate?.socketConnected?(isConnected: true)
                    break
                case "message":
                    print("message printed")
                    socketDelegate?.messageRecived?(dict:dictionary)
                    break
                case "offer":
                    socketDelegate?.sendOffer?(dict:dictionary)
                    
                break
                case "answer":
                    //write here
                    if let sdpdata = dictionary["sdp"] as? String{
                        self.videoClient?.handleAnswerReceived(withRemoteSDP: sdpdata)

                    }
                break
                case "call-accepted":
                    print("Call accepted")
                    socketDelegate?.acceptIncomingCall?(dict: dictionary)

                    break
                case "call-declined":
                    print("Call Declined")
                    socketDelegate?.declineIncomingCall?(dict: dictionary)

                    break
                case "call-initiated":
                    print("Call initiated")
                    socketDelegate?.startIncomingCall?(dict: dictionary)
                    break
                case "candidate":
                    
                    if let dataval = dictionary["candidate"] as? NSDictionary {
                        self.sdpType = "answer"
                        print("candidate printed \(dataval)")
                        var rtcIceCandidate: RTCIceCandidate {
                            return RTCIceCandidate(sdp: dataval["candidate"] as! String, sdpMLineIndex: dataval["sdpMLineIndex"] as! Int32, sdpMid: dataval["sdpMid"] as? String)
                        }
                        self.videoClient?.addIceCandidate(iceCandidate: rtcIceCandidate)
                    }
                break
                case "bye" :

                    socketDelegate?.endVCCall?(dict: dictionary)
                    self.videoClient?.disconnect()

                break
                default: break
                }
            }
        }
        
    }
    public func webSocketDidReceiveMessage(connection: WebSocketConnection, data: Data) {
        print("socket data message received")
        
    }
}
