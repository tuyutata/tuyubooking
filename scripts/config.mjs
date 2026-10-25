// 本产品配置需求的公开入口；只登记名称、类型和规则，不保存配置值。
export const manifest=Object.freeze({
  "schema": 1,
  "product_id": "tuyubooking",
  "configuration": {
    "id": "tuyubooking",
    "kind": "tuyu",
    "title": "途遇商家端配置",
    "items": [
      {
        "name": "APP_KEY",
        "description": "安卓应用正式签名材料",
        "accessLevel": "protected",
        "kind": "android-signing",
        "format": "不适用"
      },
      {
        "name": "IOS_KEY",
        "description": "苹果移动应用正式签名证书",
        "accessLevel": "protected",
        "kind": "ios-signing",
        "format": "不适用"
      },
      {
        "name": "TUYUBOOKING_PROFILE",
        "description": "途遇商家描述文件",
        "accessLevel": "protected",
        "kind": "ios-signing",
        "format": "ios_profile:com.tuyulove.tuyubooking.client"
      }
    ]
  }
});
export function describeConfiguration(){return JSON.parse(JSON.stringify(manifest));}

// 本产品Workflow坐标声明。
export const workflows=Object.freeze({"host-macos":"hostmacos.yml","host-windows":"hostwindows.yml","host-linux-arm":"hostlinuxarm.yml","host-linux-amd":"hostlinuxamd.yml","client-ios":"clientios.yml","client-android":"clientandroid.yml","client-macos":"clientmacos.yml","client-windows":"clientwindows.yml"});

// 只返回声明数据；派发与观察归通用调用方，版本及交付归本仓YAML。
export function describeAction({flow,platform,inputs={}}){
 const workflow=workflows[platform];
 if(flow==='release'&&workflow)return {repository:"tuyutata/tuyubooking",workflow,ref:'main',inputs};
 throw Error('本产品未声明该流程：'+flow+'·'+platform);
}
