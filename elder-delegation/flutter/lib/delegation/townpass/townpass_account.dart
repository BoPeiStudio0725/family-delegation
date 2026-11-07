/// 台北通帳號（只取我們需要的欄位，欄位名稱跟台北通 Account JSON 一樣）。
class TownPassAccount {
  final String id;
  final String realName;
  final String? birthday; // 例如 1988/12/12
  final String? phoneNo;
  final String? district; // 取 addresses[0].town，例如 中山區

  const TownPassAccount({
    required this.id,
    required this.realName,
    this.birthday,
    this.phoneNo,
    this.district,
  });

  factory TownPassAccount.fromJson(Map<String, dynamic> j) {
    String? town;
    final addresses = j['addresses'];
    if (addresses is List && addresses.isNotEmpty && addresses.first is Map) {
      town = (addresses.first as Map)['town']?.toString();
    }
    return TownPassAccount(
      id: '${j['id']}',
      realName: '${j['realName'] ?? j['username'] ?? '台北通使用者'}',
      birthday: j['birthday']?.toString(),
      phoneNo: j['phoneNo']?.toString(),
      district: town,
    );
  }

  Map<String, dynamic> toLoginJson() => {
        'id': id,
        'realName': realName,
        'birthday': birthday,
        'phoneNo': phoneNo,
        'district': district,
      };
}

/// 不在台北通 App 裡（例如直接用 Chrome 開發）時，給開發者選的模擬帳號。
/// 第一個就是台北通原始碼 assets/mock_data/account.json 的預設帳號。
const demoTownPassAccounts = <TownPassAccount>[
  TownPassAccount(
    id: '7f3562f4-bb3f-4ec7-89b9-da3b4b5ff250',
    realName: '金大森',
    birthday: '1988/12/12',
    phoneNo: '0932166777',
    district: '中山區',
  ),
  TownPassAccount(
    id: 'demo-townpass-grandma',
    realName: '金阿嬤',
    birthday: '1950/03/02',
    phoneNo: '0912345678',
    district: '士林區',
  ),
  TownPassAccount(
    id: 'demo-townpass-relative',
    realName: '金小妹',
    birthday: '1995/06/18',
    phoneNo: '0987654321',
    district: '大安區',
  ),
];
