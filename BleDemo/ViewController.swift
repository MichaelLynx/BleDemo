//
//  ViewController.swift
//  BleDemo
//
//  Created by Lynx on 23/03/2020.
//  Copyright © 2020 Lynx. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {

    let cellID = "cellIdentifier"
    var bleHelper = BleHelper.shared
    var pArray:[CBPeripheral] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        edgesForExtendedLayout = .top
        setUI()
        setData()
    }

    func setUI() {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        
        tableView.frame = CGRect(x: 0, y: 22, width: width, height: height - 22)
        view.addSubview(tableView)
    }
    
    func setData() {
        bleHelper.setPeripheralsBlock { (peArray) in
            self.pArray = peArray
            self.tableView.reloadData()
        }
        
        bleHelper.setConnectedBlock { (backPe, backCh) in
            print("设备已连接，peripheral:\(backPe)，characteristic:\(backCh)")
        }
        
        bleHelper.setDataBlock { (data) in
            print("ble data:\([UInt8](data))")
        }
    }
    
    //MARK: Lazy Load
    
    lazy var tableView: UITableView = {
        let tTableView = UITableView(frame: CGRect.zero)
        tTableView.delegate = self
        tTableView.dataSource = self
        tTableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        
        return tTableView
    }()
}

extension ViewController:UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        
        cell.textLabel?.text = pArray[indexPath.row].name ?? ""
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        bleHelper.doConnect(peripheral: pArray[indexPath.row])
    }
}
