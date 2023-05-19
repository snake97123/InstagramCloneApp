//
//  HomeViewController.swift
//  Instagram
//
//  Created by 山下　航 on 2023/05/12.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var postArray: [PostData] = []
    
    var listener: ListenerRegistration?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        let nib = UINib(nibName: "PostTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "Cell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("DEBUG_PRINT: viewWillAppear")
        
        if Auth.auth().currentUser != nil {
            let postRef = Firestore.firestore().collection(Const.PostPath).order(by: "date", descending: true)
            listener = postRef.addSnapshotListener() { (querySnapshot, error) in
                if let error = error {
                    print("DEBUG_PRINT: snapshotの取得が失敗しました。 \(error)")
                    return
                }
                
                self.postArray = querySnapshot!.documents.map { document in
                    let postData = PostData(document: document)
                    document.reference.collection("comments").order(by: "timestamp").addSnapshotListener { (snapshot, error) in
                        if let error = error {
                            print("DEBUG_PRINT: commentの取得が失敗しました。 \(error)")
                        } else {
                            postData.comments = snapshot!.documents.compactMap { document in
                                let commentData = document.data()
                                guard let username = commentData["username"] as? String,
                                      let text = commentData["text"] as? String else { return nil }
                                
                                return Comment(username: username, text: text)
                            }
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    }
                    print("DEBUG_PRINT: \(postData)")
                    return postData
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("DEBUG_PRINT: viewwillDisappear")
        listener?.remove()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! PostTableViewCell
        cell.setPostData(postArray[indexPath.row])
        
        cell.likeButton.addTarget(self, action: #selector(handleButton(_:forEvent:)), for: .touchUpInside)
        cell.commentButton.addTarget(self, action: #selector(didTapCommentButton(_: forEvent: )), for: .touchUpInside)
        
        return cell
    }
    
    @objc func handleButton(_ sender: UIButton, forEvent event: UIEvent) {
        print("DEBUG_PRINT: likeボタンがタップされました。")
        
        let touch = event.allTouches?.first
        let point = touch!.location(in: self.tableView)
        let indexPath = tableView.indexPathForRow(at: point)
        
        let postData = postArray[indexPath!.row]
        
        if let myid = Auth.auth().currentUser?.uid {
            var updateValue: FieldValue
            if postData.isLiked {
                updateValue = FieldValue.arrayRemove([myid])
            } else {
                updateValue = FieldValue.arrayUnion([myid])
            }
            let postRef = Firestore.firestore().collection(Const.PostPath).document(postData.id)
            postRef.updateData(["likes": updateValue])
        }
    }
    
    @objc func didTapCommentButton(_ sendar: UIButton, forEvent event: UIEvent) {
        let alertController = UIAlertController(title: "コメント", message: "コメントを入力してください", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "コメント"
        }
        
        let submitAction = UIAlertAction(title: "送信", style: .default) { _ in
            guard let text = alertController.textFields?.first?.text, !text.isEmpty else {
                return
            }
            let touch = event.allTouches?.first
            let point = touch!.location(in: self.tableView)
            let indexPath = self.tableView.indexPathForRow(at: point)
            let postData = self.postArray[indexPath!.row]
            let postId = postData.id
            let username = Auth.auth().currentUser?.displayName
            self.saveComment(postId: postId, username: username!, text: text)
            
        }
        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel)
        
        alertController.addAction(submitAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true)
    }
    
    func saveComment(postId: String, username: String, text: String) {
        let db = Firestore.firestore()
        
        let commentData: [String: Any] = [
            "username": username,
            "text": text,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("posts").document(postId).collection("comments").addDocument(data: commentData) { error in
            if let error = error {
                print("DEBUG_ERROR: error = \(error)" )
            } else {
                print("コメントの投稿に成功しました。")
            }
        }
    }
    

    
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
