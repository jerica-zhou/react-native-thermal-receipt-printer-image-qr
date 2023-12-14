package com.pinmi.react.printer.adapter;

import android.util.Log;

import com.gprinter.bean.PrinterDevices;
import com.gprinter.command.LabelCommand;
import com.gprinter.io.BluetoothPort;
import com.gprinter.io.EthernetPort;
import com.gprinter.io.PortManager;
import com.gprinter.io.SerialPort;
import com.gprinter.io.UsbPort;
import com.gprinter.utils.Command;
import com.gprinter.utils.ConnMethod;
import android.content.Context;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.Vector;

/**
 * Copyright (C), 2012-2019, 打印机有限公司
 * FileName: BLEPrinter
 * Author: Circle
 * Date: 2019/12/25 19:46
 * Description: 打印机使用单例
 */
public class BLEPrinter {
    public static BLEPrinter printer=null;
    public static PortManager portManager=null;
    private static Context context;
    public final PrinterDevices devices=null;

    public BLEPrinter(){
    }
    /**
     * 单例
     * @return
     */
    public static BLEPrinter getInstance(){
       if (printer==null){
           printer=new BLEPrinter();
       }
       return printer;
    }

    /**
     * 获取打印机管理类
     * @return
     */
    public static PortManager getPortManager(){
        return portManager;
    }

    /**
     * 获取连接状态
     * @return
     */
    public static boolean getConnectState(){
        return portManager.getConnectStatus();
    }

    public static void printParcel(String jsonData){
        try {
            if (portManager == null || getConnectState() == false) {
                throw new IOException("PRINTER_NOT_CONNECTED");
            }
            Log.v("PRINTING", jsonData);
            JSONObject data = new JSONObject(jsonData);
            String CulCode = data.getString("CulCode");
            String Name = data.getString("Name");
            String Unit = data.getString("Unit");
            String Mobile = data.getString("Mobile");
            String QRData = data.getString("QRData");

            LabelCommand tsc = new LabelCommand();
            // 设置标签尺寸宽高，按照实际尺寸设置 单位mm
            tsc.addUserCommand("\r\n");
            tsc.addSize(50, 70);
            // 设置打印方向
            tsc.addDirection(LabelCommand.DIRECTION.FORWARD, LabelCommand.MIRROR.NORMAL);
            // 设置原点坐标
            tsc.addReference(0, 0);
            // 撕纸模式开启
            tsc.addTear(LabelCommand.RESPONSE_MODE.ON);
            // 清除打印缓冲区
            tsc.addCls();

            if (CulCode.equals("EN")) {
                tsc.addText(20, 80, LabelCommand.FONTTYPE.FONT_2, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, Name);
                tsc.addText(20, 130, LabelCommand.FONTTYPE.FONT_2, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, Unit);
            }
            else if (CulCode.equals("CHS")) {
                tsc.addText(20, 80, LabelCommand.FONTTYPE.SIMPLIFIED_24_CHINESE, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, Name);
                tsc.addText(20, 130, LabelCommand.FONTTYPE.SIMPLIFIED_24_CHINESE, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, Unit);
            } else {
                tsc.addText(20, 80, LabelCommand.FONTTYPE.SIMPLIFIED_24_CHINESE, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, Name);
                tsc.addText(20, 130, LabelCommand.FONTTYPE.SIMPLIFIED_24_CHINESE, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, Unit);
            }

            //英数字
            tsc.addText(20,180, LabelCommand.FONTTYPE.FONT_2, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, Mobile);
            //绘制二维码
            tsc.addQRCode(70, 258, LabelCommand.EEC.LEVEL_L, 4, LabelCommand.ROTATION.ROTATION_0, QRData);
            // 打印标签
            tsc.addPrint(1, 1);
            // 打印标签后 蜂鸣器响
            tsc.addSound(2, 100);

            Vector<Byte> datas = tsc.getCommand();

            sendDataToPrinter(datas);
        }
        catch (JSONException | IOException e) {
            Log.e("ERR PRINTING", e.toString());
        }
    }
    public static void connectAndPrint(String mac, String jsonData){
         PrinterDevices devices = new PrinterDevices.Build()
                .setContext(context)
                .setConnMethod(ConnMethod.BLUETOOTH)
                .setMacAddress(mac)
                .setCommand(Command.TSC)
                .build();

        ThreadPoolManager.getInstance().addTask(new Runnable() {
            @Override
            public void run() {
                if (portManager != null) {
                    PrinterDevices oldDevices = portManager.getPrinterDevices();

                    // If not same, 先close上次连接
                    if (oldDevices!=null && !devices.getMacAddress().equals(oldDevices.getMacAddress())) {
                        portManager.closePort();

                        // then connect new
                        if (devices != null) {
                            portManager = new BluetoothPort(devices);
                            portManager.openPort();
                            printParcel(jsonData);
                        }
                    }
                    else {
                        // If same, keep current connected port
                        printParcel(jsonData);
                    }
                }
                else {
                    if (devices != null) {
                        portManager = new BluetoothPort(devices);
                        portManager.openPort();
                        printParcel(jsonData);
                    }
                }
            }
        });
    }

    /**
     * 连接
     * @param devices
     */
    public static void connect(final PrinterDevices devices){
        ThreadPoolManager.getInstance().addTask(new Runnable() {
            @Override
            public void run() {
                if (portManager != null) {
                    PrinterDevices oldDevices = portManager.getPrinterDevices();

                    // If not same, 先close上次连接
                    if (oldDevices!=null && !devices.getMacAddress().equals(oldDevices.getMacAddress())) {
                        portManager.closePort();

                        // then connect new
                        if (devices != null) {
                            portManager = new BluetoothPort(devices);
                            portManager.openPort();
                        }
                        try {
                            Thread.sleep(2000);
                        } catch (InterruptedException e) {
                        }
                    }
                    // If same, keep current connected port
                }
                else {
                    if (devices != null) {
                        portManager = new BluetoothPort(devices);
                        portManager.openPort();
                    }
                }
            }
        });
    }
    /**
     * 发送数据到打印机 字节数据
     * @param vector
     * @return true发送成功 false 发送失败
     * 打印机连接异常或断开发送时会抛异常，可以捕获异常进行处理
     */
    public static boolean sendDataToPrinter(byte [] vector) throws IOException {
        if (portManager==null){
            return false;
        }
        return portManager.writeDataImmediately(vector);
    }

    /**
     * 获取打印机状态
     * @param printerCommand 打印机命令 ESC为小票，TSC为标签 ，CPCL为面单
     * @return 返回值常见文档说明
     * @throws IOException
     */
    public static int getPrinterState(Command printerCommand, long delayMillis)throws IOException {
        return portManager.getPrinterStatus(printerCommand);
    }

    /**
     * 获取打印机电量
     * @return
     * @throws IOException
     */
    public static int getPower() throws IOException {
        return portManager.getPower();
    }
    /**
     * 获取打印机指令
     * @return
     */
    public static Command getPrinterCommand(){
        return portManager.getCommand();
    }

    /**
     * 设置使用指令
     * @param printerCommand
     */
    public static void setPrinterCommand(Command printerCommand){
        if (portManager==null){
            return;
        }
        portManager.setCommand(printerCommand);
    }
    /**
     * 发送数据到打印机 指令集合内容
     * @param vector
     * @return true发送成功 false 发送失败
     * 打印机连接异常或断开发送时会抛异常，可以捕获异常进行处理
     */
    public static boolean sendDataToPrinter(Vector<Byte> vector) throws IOException {
        if (portManager==null){
            return false;
        }
        return portManager.writeDataImmediately(vector);
    }
    /**
     * 关闭连接
     * @return
     */
    public static void close(){
        if (portManager!=null){
             portManager.closePort();
             portManager=null;
        }
    }
}
