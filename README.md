> 之前做过蓝牙连接的功能，但是要么是直接在别人的基础上更改和新增功能，要么就是囫囵吞枣直接按别人的文章一步步写过去，写完了自己也还是没有头绪，仅仅是能用而已。这次借设计YModem升级工具及蓝牙多设备同时升级功能的机会，从头梳理一遍蓝牙连接的功能，并记之以文字。



# 一、原理

> 更详细信息可以查看官方蓝牙框架文档：[《Core Bluetooth Programming Guide》](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/AboutCoreBluetooth/Introduction.html#//apple_ref/doc/uid/TP40013257-CH1-SW1)
>
> 文章链接：[蓝牙连接（swift版）](https://michaellynx.github.io/bluetooth-for-swift/)



## 1.基本概念

### 1.1 蓝牙版本

#### 蓝牙2.0

蓝牙2.0是传统蓝牙，也叫做经典蓝牙。

蓝牙2.0如要上架需进行MFI认证，使用ExternalAccessory框架。

#### 蓝牙4.0

蓝牙4.0因为耗电低，也叫做低功耗蓝牙(BLE)。它将三种规格集于一体，包括传统蓝牙技术、高速技术和低耗能技术。

蓝牙4.0使用CoreBluetooth框架。



### 1.2 参数

#### 基本参数

- CBCentralManager：中心设备，连接硬件的设备。
- CBPeripheral：外围设备，被连接的硬件。
- service：服务
- characteristic：特征

一个外设包含多个服务,而每一个服务中又包含多个特征,特征包括特征的值和特征的描述.每个服务包含多个字段,字段的权限有read(读)、write(写)、notify(通知/订阅)。



#### characteristic的三种操作：

- write：发送信息给外围设备

- notify：接收外围设备的通知

- read：获取外围设备的信息。当部分设备为只读时，无法使用write发送信息给外围设备，但可以使用read去获取外围设备的信息。

正常多使用write和notify。



## 2.模式

蓝牙开发分为两种模式，中心模式(central)，和外设模式(peripheral)。一般来讲，我们需要在软件内连接硬件，通过连接硬件给硬件发送指令以完成一些动作的蓝牙开发都是基于中心模式(central)模式的开发，也就是说我们开发的app是中心，我们要连接的硬件是外设。如果需要其他设备连接手机蓝牙，并对手机进行一些操作，那就是基于外设模式(peripheral)的开发。



### 中心模式流程

**swift版：**

1. 创建中心设备(CBCentralManager)
2. 中心设备开始扫描(scanForPeripherals)
3. 扫描到外围设备之后, 自动调用中心设备的代理方法(didDiscoverPeripheral)
4. 如果设备过多, 可以将扫描到的外围设备添加到数组
5. 开始连接, 从数组中过滤出自己想要的设备, 进行连接(connectPeripheral)
6. 连接上之后, 自动调用中心设备的代理方法(didConnectPeripheral), 在代理中, 进行查找外围设备的服务(peripheral.discoverServices)
7. 查找到服务之后, 自动调用外围设备的代理(didDiscoverServices), 可通过UUID,查找具体的服务,查找服务(discoverCharacteristics)
8. 查找到特征之后, 自动调用外围设备的代理(didDiscoverCharacteristics), 通过UUID找到自己想要的特征, 读取特征(readValueForCharacteristic)
9. 读取到特征之后, 自动调用外设的代理方法(didUpdateValueForCharacteristic),在这里打印或者解析自己想要的特征值.

**oc版：**

1. 建立中心角色 [[CBCentralManager alloc] initWithDelegate:self queue:nil]
2. 扫描外设 cancelPeripheralConnection
3. 发现外设 didDiscoverPeripheral
4. 连接外设 connectPeripheral
   - 4.1连接失败 didFailToConnectPeripheral
   - 4.2连接断开 didDisconnectPeripheral
   - 4.3连接成功 didConnectPeripheral
5. 扫描外设中的服务 discoverServices
   - 5.1发现并获取外设中的服务 didDiscoverServices
6. 扫描外设对应服务的特征 discoverCharacteristics
   - 6.1发现并获取外设对应服务的特征 didDiscoverCharacteristicsForService
   - 6.2给对应特征写数据 writeValue:forCharacteristic:type:
7. 订阅特征的通知 setNotifyValue:forCharacteristic:
   - 7.1根据特征读取数据 didUpdateValueForCharacteristic



### 外设模式流程

1. 建立外设设备
2. 设置本地外设的服务和特征
3. 发布外设和特征
4. 广播服务
5. 响应中心的读写请求
6. 发送更新的特征值，订阅中心

<br>



# 二、实现

> **常用方法**记录用到的方法，**代码**是具体运用



## 2.1 前置

- 设备的特征包含UUID，可通过UUID区分对应的特征。
- 要用到蓝牙连接相关类的页面需导入头文件：`import CoreBluetooth`



### 变量

```swift
private let BLE_WRITE_UUID = "xxxx"
private let BLE_NOTIFY_UUID = "xxxx"

var centralManager:CBCentralManager?
///扫描到的所有设备
var aPeArray:[CBPeripheral] = []
//当前连接的设备
var pe:CBPeripheral?
var writeCh: CBCharacteristic?
var notifyCh: CBCharacteristic?
```



### 常用方法

实例化

```swift
var centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
```

开始扫描

```swift
centralManager.scanForPeripherals(withServices: serviceUUIDS, options: nil)
```

连接设备

```swift
centralManager.connect(peripheral, options: nil)
```

- 连接设备之前要先设置代理，正常情况，当第一次获取外设peripheral的时候就会同时设置代理

断开连接

```swift
centralManager.cancelPeripheralConnection(peripheral)
```

停止扫描

```swift
centralManager.stopScan()
```

发现服务

```swift
peripheral.discoverServices(nil)
```

- 外设连接成功的时候使用该方法发现服务
- 一般在此处同步设置代理：`peripheral.delegate = self`

发现特征

```swift
peripheral.discoverCharacteristics(nil, for: service)
```

- 搜索到服务之后执行该方法，将特征下的服务`peripheral.services`对应搜索特征

设置通知

```swift
peripheral.setNotifyValue(true, for: characteristic)
```

- 当搜索到对应特征之后，可以根据条件判断是否设置及保存该特征，如特征的uuid
- 通知的特征需要设置该项，以开启通知



## 2.2 代码



### 2.2.1 流程



#### 实例化

将CBCenteralManager实例化：

```swift
centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey:false])
```

实例化完成后的回调：

```swift
func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == CBManagerState.poweredOn {
            print("powered on")
            
        } else {
            if central.state == CBManagerState.poweredOff {
                print("BLE powered off")
            } else if central.state == CBManagerState.unauthorized {
                print("BLE unauthorized")
            } else if central.state == CBManagerState.unknown {
                print("BLE unknown")
            } else if central.state == CBManagerState.resetting {
                print("BLE ressetting")
            }
        }
}
```

- CBCenteralManager实例化完毕，可以开始扫描外设`CBPeripheral`
- 如无特殊要求，可以在此处直接进行扫描操作



#### 扫描并发现设备

扫描设备：

```swift
centralManager.scanForPeripherals(withServices: serviceUUIDS, options: nil)
```

发现设备：

```swift
func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    guard !aPeArray.contains(peripheral), let deviceName = peripheral.name, deviceName.count > 0 else {
        return
    }
    
}
```

- 此处可以将搜索到的设备保存并显示出来，也可以将需要的设备直接连接



#### 连接设备

连接设备：

```swift
centralManager.connect(peripheral, options: nil)
```

设备连接完成后的回调：

```swift
func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("\(#function)连接外设成功。\ncentral:\(central),peripheral:\(peripheral)\n")
    // 设置代理
    peripheral.delegate = self
    // 开始发现服务
    peripheral.discoverServices(nil)
}
```

- 连接完成后直接搜索对应的服务`Service`

设备连接失败的回调：

```swift
func centralManager(_ central: CBCentralManager, didFailToConnect peripheral:
CBPeripheral, error: Error?) {
    print("\(#function)连接外设失败\n\(String(describing:
peripheral.name))连接失败：\(String(describing: error))\n")
    // 这里可以发通知出去告诉设备连接界面连接失败
    
}
```

连接丢失的回调：

```swift
func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    print("\(#function)连接丢失\n外设：\(String(describing:
peripheral.name))\n错误：\(String(describing: error))\n")
    // 这里可以发通知出去告诉设备连接界面连接丢失
    
}
```



#### 搜索服务

搜索服务（设备连接成功的回调处执行）：

```swift
peripheral.discoverServices(nil)
```

发现服务：

```swift
func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error = error  {
        print("\(#function)搜索到服务-出错\n设备(peripheral)：\(String(describing:
peripheral.name)) 搜索服务(Services)失败：\(error)\n")
        return
    } else {
        print("\(#function)搜索到服务\n设备(peripheral)：\(String(describing:
peripheral.name))\n")
    }
    for service in peripheral.services ?? [] {
        peripheral.discoverCharacteristics(nil, for: service)
    }
}
```

- 搜索到服务之后直接搜索其对应的特征



#### 搜索特征

搜索特征（当发现服务之后即执行搜索）：

```swift
peripheral.discoverCharacteristics(nil, for: service)
```

发现特征

```swift
func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if let _ = error {
        print("\(#function)发现特征\n设备(peripheral)：\(String(describing: peripheral.name))\n服务(service)：\(String(describing: service))\n扫描特征(Characteristics)失败：\(String(describing: error))\n")
        return
    } else {
        print("\(#function)发现特征\n设备(peripheral)：\(String(describing: peripheral.name))\n服务(service)：\(String(describing: service))\n服务下的特征：\(service.characteristics ?? [])\n")
    }
    
    for characteristic in service.characteristics ?? [] {
        if characteristic.uuid.uuidString.lowercased().isEqual(BLE_WRITE_UUID) {
            pe = peripheral
            writeCh = characteristic
        } else if characteristic.uuid.uuidString.lowercased().isEqual(BLE_NOTIFY_UUID) {
            notifyCh = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
        //此处代表连接成功
    }
}
```

- 此处可保存连接设备外设`peripheral`和特征`characteristic`，后续发送接收数据时使用
- swift的UUID与oc的不一样，要区分大小写，故UUID最好保存为字符串
- 连接成功可在此处设置回调



#### 读取设备发送的数据

获取设备发送的数据：

```swift
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic:
CBCharacteristic, error: Error?) {
    if let _ = error {
        return
    }
    //拿到设备发送过来的值,可传出去并进行处理
    
}
```

- 设备发送过来的数据会在此处回调，可设置闭包、协议等回调方式将值传出去



#### 向设备发送数据

发送数据：

```swift
peripheral.writeValue(data, for: characteristic, type: .withResponse)
```

- 类型根据需要填写
- 特征`characteristic`需要是写入的特征，不能用其他的特征

检测发送数据是否成功：

```swift
func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error = error {
        print("\(#function)\n发送数据失败！错误信息：\(error)")
    }
}
```



### 2.2.2 完整代码下载

github代码：[BleDemo](https://github.com/MichaelLynx/BleDemo)

欢迎相互学习交流，也欢迎去github点个star。

