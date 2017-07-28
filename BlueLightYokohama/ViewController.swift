//
//  ViewController.swift
//  BLEWriteExample
//
//  Created by Shuichi Tsutsumi on 2014/12/12.
//  Copyright (c) 2014 Shuichi Tsutsumi. All rights reserved.
//

import UIKit
import CoreBluetooth
import Orphe

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, ORPManagerDelegate {

    fileprivate var isScanning = false
    fileprivate var centralManager: CBCentralManager!
    // fileprivate var peripheral: CBPeripheral!
    fileprivate var peripherals: [CBPeripheral] = []
    fileprivate var peripheral1: CBPeripheral!
    fileprivate var peripheral2: CBPeripheral!
    fileprivate var isSet = false;
    //fileprivate var settingCharacteristic: CBCharacteristic!
    //fileprivate var outputCharacteristic: CBCharacteristic!
    
    fileprivate var settingCharacteristics: [CBCharacteristic] = []
    fileprivate var outputCharacteristics: [CBCharacteristic] = []
    
    fileprivate var rssis: [Int] = []
    
    fileprivate var isOn = false;
    
    @IBOutlet weak var scanBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // セントラルマネージャ初期化
        centralManager = CBCentralManager(delegate: self, queue: nil)
        ORPManager.sharedInstance.delegate = self
        Timer.scheduledTimer(timeInterval: 2, target: self, selector: "ledBtnTapped", userInfo: nil, repeats: true);
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // =========================================================================
    // MARK: CBCentralManagerDelegate
    
    // セントラルマネージャの状態が変化すると呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("state: \(central.state)")
    }
    
    // ペリフェラルを発見すると呼ばれる
    func centralManager(_ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber)
    {
        print("発見したBLEデバイス: \(peripheral)")
        self.peripherals.append(peripheral)
        
        // 接続開始
        let dictionary: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey : true
        ]
        centralManager.connect(peripheral, options: dictionary)
    }
    
    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager,
        didConnect peripheral: CBPeripheral)
    {
        print("接続成功！")

        // サービス探索結果を受け取るためにデリゲートをセット
        peripheral.delegate = self
        
        // konashiサービスを探索開始
        peripheral.discoverServices([CBUUID(string: "713D0000-503E-4C75-BA94-3148F18D941E")])
    }
    
    // ペリフェラルへの接続が失敗すると呼ばれる
    func centralManager(_ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?)
    {
        print("接続失敗・・・")
    }
    
    // =========================================================================
    // MARK:CBPeripheralDelegate
    
    // サービス発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if let error = error {
            print("エラー: \(error)")
            return
        }
        
        guard let services = peripheral.services, services.count > 0 else {
            print("no services")
            return
        }
        print("\(services.count) 個のサービスを発見！ \(services)")

        for service in services {
            // キャラクタリスティックを探索開始
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // キャラクタリスティック発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?)
    {
        if let error = error {
            print("エラー: \(error)")
            return
        }
        
        guard let characteristics = service.characteristics, characteristics.count > 0 else {
            print("no characteristics")
            return
        }
        print("\(characteristics.count) 個のキャラクタリスティックを発見！ \(characteristics)")
        
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(CBUUID(string: "713D0003-503E-4C75-BA94-3148F18D941E")) {
                // settingCharacteristic = characteristic
                settingCharacteristics.append(characteristic)
                print("KONASHI_PIO_SETTING_UUID を発見！")
            } else if characteristic.uuid.isEqual(CBUUID(string: "713D0002-503E-4C75-BA94-3148F18D941E")) {
                // outputCharacteristic = characteristic
                outputCharacteristics.append(characteristic)
                print("KONASHI_PIO_OUTPUT_UUID を発見！")
            }
        }
    }

    // データ書き込みが完了すると呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?)
    {
        if let error = error {
            print("書き込み失敗...error: \(error), characteristic uuid: \(characteristic.uuid)")
            return
        }
        
        print("書き込み成功！service uuid: \(characteristic.service.uuid), characteristic uuid: \(characteristic.uuid), value: \(characteristic.value)")
    }
    
    // read
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
        if let error = error {
            print("読み出し失敗...error: \(error), characteristic uuid: \(characteristic.uuid)")
            return
        }
        
        print("読み出し成功！service uuid: \(characteristic.service.uuid), characteristic uuid: \(characteristic.uuid), value: \(characteristic.value)")
        
        var byte: CUnsignedChar = 0
            
        // 1バイト取り出す
        (characteristic.value as NSData?)?.getBytes(&byte, length: 1)
            
        print("Battery Level: \(byte)")
    }
    
    // RSSIのREADで呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didReadRSSI RSSI: NSNumber,
                    error: Error?) {
        let rssi = RSSI.intValue;
        self.rssis.append(rssi);
        print(rssi);
    }
    
    
    
    // =========================================================================
    // MARK: Actions

    @IBAction func scanBtnTapped(_ sender: UIButton) {
        let cbuuid = CBUUID.init(string:"713D0000-503E-4C75-BA94-3148F18D941E")
        if !isScanning {
            isScanning = true
            centralManager.scanForPeripherals(withServices: [cbuuid], options: nil)
            sender.setTitle("STOP SCAN", for: UIControlState())
        } else {
            centralManager.stopScan()
            sender.setTitle("START SCAN", for: UIControlState())
            isScanning = false
        }
    }


    //@IBAction func ledBtnTapped(_ sender: UIButton) {
    func ledBtnTapped() {
        
        // LEDを光らせる
        var buf: [UInt8] = [0x01, 0x01, 0x00] // <- 適当な値で大丈夫

        
        let data = Data(buffer: UnsafeBufferPointer(start: &buf, count: 3))
        print(peripherals.count)
        var count = 0;
        var isNear = true;
            
        for peripheral in self.peripherals {
            if(peripheral.state == CBPeripheralState.connected){
                count = count+1;
            }
        }
        if(count < 2){
            return;
        }
        
        for peripheral in peripherals {
            peripheral.readRSSI();
        }
        for rssi in rssis{
            if(rssi < -70){
                isNear = false;
            }
        }
        rssis = [];
        if(isNear == isOn){
            return;
        }
        print("send message");
        for peripheral in self.peripherals {
            print(peripheral.state == CBPeripheralState.connected)
            for settingCharacteristic in settingCharacteristics{
                peripheral.writeValue(
                    data as Data,
                    for: settingCharacteristic,
                    type: CBCharacteristicWriteType.withoutResponse)
            }
        }
        ORPManager.sharedInstance.startScan()
        for orphe in ORPManager.sharedInstance.availableORPDataArray{
            print("orphe is here!!!")
            ORPManager.sharedInstance.connect(orphe: orphe)
            print("connected")
            orphe.setColorRGB(lightNum: 128, red:0, green:0, blue:255)
            //orphe.switchLight(lightNum: 128, flag: true)
        }
        
        
        isOn = !isOn;
    }
}
