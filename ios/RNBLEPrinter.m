#import <Foundation/Foundation.h>

#import "RNBLEPrinter.h"
#import "PrinterSDK.h"
#import "TscCommand.h"
#import "ConnecterManager.h"

@implementation RNBLEPrinter

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(init:(RCTResponseSenderBlock)successCallback
                  fail:(RCTResponseSenderBlock)errorCallback) {
    @try {
        _printerArray = [NSMutableArray new];
        m_printer = [[NSObject alloc] init];
        peripheralDicts = [NSMutableDictionary new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetPrinterConnectedNotification:) name:@"NetPrinterConnected" object:nil];
        // API MISUSE: <CBCentralManager> can only accept this command while in the powered on state
        [[PrinterSDK defaultPrinterSDK] scanPrintersWithCompletion:^(Printer* printer){}];
        successCallback(@[@"Init successful"]);
    } @catch (NSException *exception) {
        errorCallback(@[@"No bluetooth adapter available"]);
    }
}

- (void)handleNetPrinterConnectedNotification:(NSNotification*)notification
{
    m_printer = nil;
}

/*
RCT_EXPORT_METHOD(getDeviceList:(RCTResponseSenderBlock)successCallback
                  fail:(RCTResponseSenderBlock)errorCallback) {
    @try {
        !_printerArray ? [NSException raise:@"Null pointer exception" format:@"Must call init function first"] : nil;
        [[PrinterSDK defaultPrinterSDK] scanPrintersWithCompletion:^(Printer* printer){
            [_printerArray addObject:printer];
            NSMutableArray *mapped = [NSMutableArray arrayWithCapacity:[_printerArray count]];
            [_printerArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSDictionary *dict = @{ @"device_name" : printer.name, @"inner_mac_address" : printer.UUIDString};
                [mapped addObject:dict];
            }];
            NSMutableArray *uniquearray = (NSMutableArray *)[[NSSet setWithArray:mapped] allObjects];;
            successCallback(@[uniquearray]);
        }];
    } @catch (NSException *exception) {
        errorCallback(@[exception.reason]);
    }
}
*/

-(void) startScane:(RCTResponseSenderBlock)successCallback
              fail:(RCTResponseSenderBlock)errorCallback {
    @try {
        NSMutableDictionary *dicts = [[NSMutableDictionary alloc] init];
        [Manager scanForPeripheralsWithServices:nil options:nil discover:^(CBPeripheral * _Nullable peripheral, NSDictionary<NSString *,id> * _Nullable advertisementData, NSNumber * _Nullable RSSI) {
            if (peripheral.name != nil) {
                NSDictionary *item = @{ @"device_name": peripheral.name, @"inner_mac_address": peripheral.identifier.UUIDString };
                [dicts setObject:item forKey:peripheral.identifier.UUIDString];
                NSLog(@"name=======%@uuid===%@", peripheral.name, peripheral.identifier.UUIDString);
                [self->peripheralDicts setObject:peripheral forKey:peripheral.identifier.UUIDString];
                
                if ([peripheral.name containsString:@"GP-M322"]) {
                    [Manager stopScan];
                    NSArray *mapped = [dicts allValues];
                    
                    NSArray *uniquearray = (NSArray *)[[NSSet setWithArray:mapped] allObjects];;
                    successCallback(@[uniquearray]);
                }
            }
        }];
    } @catch (NSException *exception) {
        errorCallback(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(getDeviceList:(RCTResponseSenderBlock)successCallback
                  fail:(RCTResponseSenderBlock)errorCallback) {
    [Manager stopScan];
    if (Manager.bleConnecter == nil) {
        __weak __typeof(self)weakSelf = self;
        [Manager didUpdateState:^(NSInteger state) {
             __strong __typeof(weakSelf)strongSelf = weakSelf;
            switch (state) {
                case CBManagerStateUnsupported:
                    NSLog(@"The platform/hardware doesn't support Bluetooth Low Energy.");
                    break;
                case CBManagerStateUnauthorized:
                    NSLog(@"The app is not authorized to use Bluetooth Low Energy.");
                    break;
                case CBManagerStatePoweredOff:
                    // 未连接
                    [Manager stopScan];
                    [Manager setIsConnected:NO];
                    NSLog(@"Bluetooth is currently powered off.");
                    break;
                case CBManagerStatePoweredOn:
                    [strongSelf startScane:successCallback fail:errorCallback];
                    NSLog(@"Bluetooth power on");
                    break;
                case CBManagerStateUnknown:
                default:
                    break;
            }
        }];
    } else {
        [self startScane:successCallback fail:errorCallback];
    }
}

RCT_EXPORT_METHOD(stopScanne) {
    @try {
      [Manager stopScan];
    } @catch (NSException *exception) {
      NSLog(@"%@", exception.reason);
    }
}

RCT_EXPORT_METHOD(connectAndPrint:(NSString *)inner_mac_address
                  :(NSString *)jsonStr
                  success:(RCTResponseSenderBlock)successCallback
                  fail:(RCTResponseSenderBlock)errorCallback) {
    @try {
        if ([Manager isConnected] && [[Manager UUIDString] isEqualToString:inner_mac_address]) {
            [Manager write:[self printParcel:jsonStr] receCallBack:^(NSData *data) {}];
        } else {
            if (![Manager isConnected]) {
                NSLog(@"Not connected");
                //connect first ->
            }
            else {
                //close and re-connect ->
                NSLog(@"Connected to other printer, so close first");
                [Manager close];
            }
            CBPeripheral *peripheral = peripheralDicts[inner_mac_address];
                
            //NSLog(@"peripheral -> %@", peripheral.name);
            Manager.currentConnMethod = BLUETOOTH;
            
            [Manager connectPeripheral:peripheral options:nil timeout:2 connectBlack:^(ConnectState state) {
                switch (state) {
                    case CONNECT_STATE_CONNECTED:
                        NSLog(@"/////连接成功");
                        Manager.isConnected = YES;
                        Manager.UUIDString = peripheral.identifier.UUIDString;
                        
                        [Manager write:[self printParcel:jsonStr] receCallBack:^(NSData *data) {}];
                        
                        break;
                    case CONNECT_STATE_CONNECTING:
                        NSLog(@"////连接中....");
                        break;
                    default:
                        NSLog(@"/////连接失败");
                        Manager.isConnected = NO;
                        break;
                }
            }];
        }
    } @catch (NSException *exception) {
        errorCallback(@[exception.reason]);
    }
}

-(NSData *)printParcel:(NSString *) jsonStr {
    TscCommand *command = [[TscCommand alloc]init];
    [command addSize:50 :70];
    //[command addGapWithM:2 withN:0];
    [command addReference:0 :0];
    [command addTear:@"ON"];
    [command addQueryPrinterStatus:ON];
    [command addCls];

    NSMutableDictionary *dict=[NSJSONSerialization JSONObjectWithData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    
    NSString *CulCode = [dict valueForKey:@"CulCode"];
    NSString *Name = [dict valueForKey:@"Name"];
    NSString *Unit = [dict valueForKey:@"Unit"];
    NSString *Mobile = [dict valueForKey:@"Mobile"];
    NSString *QRData = [dict valueForKey:@"QRData"];
    
    NSLog(@"Name:%@", Name);
    
    if ([CulCode isEqualToString:(@"EN")]) {
        [command addTextwithX:20 withY:80 withFont:@"2" withRotation:0 withXscal:1 withYscal:1 withText:Name];
        [command addTextwithX:20 withY:130 withFont:@"2" withRotation:0 withXscal:1 withYscal:1 withText:Unit];
    } else if ([CulCode isEqualToString:(@"CHS")]) {
        [command addTextwithX:20 withY:80 withFont:@"TSS24.BF2" withRotation:0 withXscal:1 withYscal:1 withText:Name];
        [command addTextwithX:20 withY:130 withFont:@"TSS24.BF2" withRotation:0 withXscal:1 withYscal:1 withText:Unit];
    } else {
        [command addTextwithX:20 withY:80 withFont:@"TSS24.BF2" withRotation:0 withXscal:1 withYscal:1 withText:Name];
        [command addTextwithX:20 withY:130 withFont:@"TSS24.BF2" withRotation:0 withXscal:1 withYscal:1 withText:Unit];
    }
    [command addTextwithX:20 withY:180 withFont:@"2" withRotation:0 withXscal:1 withYscal:1 withText:Mobile];
    [command addQRCode:70 :258 :@"L" :4 :@"A" :0 :QRData];
    
    [command addPrint:1 :1];
    [command addSound:2 :100];
    [command queryPrinterStatus]; // 添加该指令可返回打印机状态，若不需要则屏蔽
    return [command getCommand];
}


RCT_EXPORT_METHOD(connectPrinter:(NSString *)inner_mac_address
                  success:(RCTResponseSenderBlock)successCallback
                  fail:(RCTResponseSenderBlock)errorCallback) {
    @try {
        __block BOOL found = NO;
        __block Printer* selectedPrinter = nil;
        [_printerArray enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop){
            selectedPrinter = (Printer *)obj;
            if ([inner_mac_address isEqualToString:(selectedPrinter.UUIDString)]) {
                found = YES;
                *stop = YES;
            }
        }];

        if (found) {
            [[PrinterSDK defaultPrinterSDK] connectBT:selectedPrinter];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEPrinterConnected" object:nil];
            m_printer = selectedPrinter;
            successCallback(@[[NSString stringWithFormat:@"Connected to printer %@", selectedPrinter.name]]);
        } else {
            [NSException raise:@"Invalid connection" format:@"connectPrinter: Can't connect to printer %@", inner_mac_address];
        }
    } @catch (NSException *exception) {
        errorCallback(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(printRawData:(NSString *)text
                  printerOptions:(NSDictionary *)options
                  fail:(RCTResponseSenderBlock)errorCallback) {
    @try {
        !m_printer ? [NSException raise:@"Invalid connection" format:@"printRawData: Can't connect to printer"] : nil;

        NSNumber* boldPtr = [options valueForKey:@"bold"];
        NSNumber* alignCenterPtr = [options valueForKey:@"center"];

        BOOL bold = (BOOL)[boldPtr intValue];
        BOOL alignCenter = (BOOL)[alignCenterPtr intValue];

        bold ? [[PrinterSDK defaultPrinterSDK] sendHex:@"1B2108"] : [[PrinterSDK defaultPrinterSDK] sendHex:@"1B2100"];
        alignCenter ? [[PrinterSDK defaultPrinterSDK] sendHex:@"1B6102"] : [[PrinterSDK defaultPrinterSDK] sendHex:@"1B6101"];
        [[PrinterSDK defaultPrinterSDK] printText:text];

        NSNumber* beepPtr = [options valueForKey:@"beep"];
        NSNumber* cutPtr = [options valueForKey:@"cut"];

        BOOL beep = (BOOL)[beepPtr intValue];
        BOOL cut = (BOOL)[cutPtr intValue];

        beep ? [[PrinterSDK defaultPrinterSDK] beep] : nil;
        cut ? [[PrinterSDK defaultPrinterSDK] cutPaper] : nil;

    } @catch (NSException *exception) {
        errorCallback(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(printImageData:(NSString *)imgUrl
                  printerOptions:(NSDictionary *)options
                  fail:(RCTResponseSenderBlock)errorCallback) {
    @try {

        !m_printer ? [NSException raise:@"Invalid connection" format:@"Can't connect to printer"] : nil;
        NSURL* url = [NSURL URLWithString:imgUrl];
        NSData* imageData = [NSData dataWithContentsOfURL:url];

        NSString* printerWidthType = [options valueForKey:@"printerWidthType"];

        NSInteger printerWidth = 576;

        if(printerWidthType != nil && [printerWidthType isEqualToString:@"58"]) {
            printerWidth = 384;
        }

        if(imageData != nil){
            UIImage* image = [UIImage imageWithData:imageData];
            UIImage* printImage = [self getPrintImage:image printerOptions:options];

            [[PrinterSDK defaultPrinterSDK] setPrintWidth:printerWidth];
            [[PrinterSDK defaultPrinterSDK] printImage:printImage ];
        }

    } @catch (NSException *exception) {
        errorCallback(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(printImageBase64:(NSString *)base64Qr
                  printerOptions:(NSDictionary *)options
                  fail:(RCTResponseSenderBlock)errorCallback) {
    @try {

        !m_printer ? [NSException raise:@"Invalid connection" format:@"Can't connect to printer"] : nil;
        if(![base64Qr  isEqual: @""]){
            NSString *result = [@"data:image/png;base64," stringByAppendingString:base64Qr];
            NSURL *url = [NSURL URLWithString:result];
            NSData *imageData = [NSData dataWithContentsOfURL:url];
            NSString* printerWidthType = [options valueForKey:@"printerWidthType"];

            NSInteger printerWidth = 576;

            if(printerWidthType != nil && [printerWidthType isEqualToString:@"58"]) {
                printerWidth = 384;
            }

            if(imageData != nil){
                UIImage* image = [UIImage imageWithData:imageData];
                UIImage* printImage = [self getPrintImage:image printerOptions:options];

                [[PrinterSDK defaultPrinterSDK] setPrintWidth:printerWidth];
                [[PrinterSDK defaultPrinterSDK] printImage:printImage ];
            }
        }
    } @catch (NSException *exception) {
        errorCallback(@[exception.reason]);
    }
}

-(UIImage *)getPrintImage:(UIImage *)image
           printerOptions:(NSDictionary *)options {
   NSNumber* nWidth = [options valueForKey:@"imageWidth"];
   NSNumber* nHeight = [options valueForKey:@"imageHeight"];
   NSNumber* nPaddingX = [options valueForKey:@"paddingX"];

   CGFloat newWidth = 150;
   if(nWidth != nil) {
       newWidth = [nWidth floatValue];
   }

   CGFloat newHeight = image.size.height;
   if(nHeight != nil) {
       newHeight = [nHeight floatValue];
   }

   CGFloat paddingX = 250;
   if(nPaddingX != nil) {
       paddingX = [nPaddingX floatValue];
   }

   CGFloat _newHeight = newHeight;
   CGSize newSize = CGSizeMake(newWidth, _newHeight);
   UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
   CGContextRef context = UIGraphicsGetCurrentContext();
   CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
   CGImageRef immageRef = image.CGImage;
   CGContextDrawImage(context, CGRectMake(0, 0, newWidth, newHeight), immageRef);
   CGImageRef newImageRef = CGBitmapContextCreateImage(context);
   UIImage* newImage = [UIImage imageWithCGImage:newImageRef];

   CGImageRelease(newImageRef);
   UIGraphicsEndImageContext();

   UIImage* paddedImage = [self addImagePadding:newImage paddingX:paddingX paddingY:0];
   return paddedImage;
}

-(UIImage *)addImagePadding:(UIImage * )image
                   paddingX: (CGFloat) paddingX
                   paddingY: (CGFloat) paddingY
{
    CGFloat width = image.size.width + paddingX;
    CGFloat height = image.size.height + paddingY;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), true, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGFloat originX = (width - image.size.width)/2;
    CGFloat originY = (height -  image.size.height)/2;
    CGImageRef immageRef = image.CGImage;
    CGContextDrawImage(context, CGRectMake(originX, originY, image.size.width, image.size.height), immageRef);
    CGImageRef newImageRef = CGBitmapContextCreateImage(context);
    UIImage* paddedImage = [UIImage imageWithCGImage:newImageRef];

    CGImageRelease(newImageRef);
    UIGraphicsEndImageContext();

    return paddedImage;
}

RCT_EXPORT_METHOD(closeConn) {
    @try {
        !m_printer ? [NSException raise:@"Invalid connection" format:@"closeConn: Can't connect to printer"] : nil;
        [[PrinterSDK defaultPrinterSDK] disconnect];
        m_printer = nil;
        [Manager close];
    } @catch (NSException *exception) {
        NSLog(@"%@", exception.reason);
    }
}

@end

