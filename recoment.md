ຂໍ້ຄວນຈຳ (USB)
Backend ຕ້ອງແລ່ນຢູ່ (ຂ້ອຍເປີດໄວ້ໃຫ້ແລ້ວ port 3000)
adb reverse ຕັ້ງໄວ້ແລ້ວ ✅ — ແຕ່ຖ້າ ຖອດສາຍ/ສຽບໃໝ່ ໃຫ້ run ຄືນ:

adb reverse tcp:3000 tcp:3000
ຖ້າຢາກ hot reload ຕອນແກ້ code: cd mobile && flutter run -d e23ddfb9

cd "c:/Users/advice/Documents/ptk/LTS_Checkin/mobile" && flutter build apk --debug 2>&1 | 
tail -3 && echo "=== install ===" &&
 adb install -r build/app/outputs/flutter-apk/app-debug.apk 2>&1 | tail -2 && adb reverse tcp:3000 tcp:3000 >/dev/null 2>&1 && adb shell monkey -p la.hrapp.hr_app -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 && echo "launched"





ນີ້ຄືຄຳສັ່ງ Flutter ທີ່ໃຊ້ເລື້ອຍໆ ສຳລັບໂປຣເຈັກນີ້ (ໃຫ້ເປີດ terminal ຢູ່ໂຟນເດີ້ mobile ກ່ອນ):

📂 ເຂົ້າໂຟນເດີ້ກ່ອນ

cd c:/Users/advice/Documents/ptk/LTS_Checkin/mobile
▶️ Run app (ໃສ່ມືຖືຈິງ ຜ່ານ USB)

# 1. forward port ໃຫ້ມືຖືຕໍ່ backend (ໃຊ້ localhost)
adb reverse tcp:3000 tcp:3000

# 2. ຕ້ອງໃຫ້ backend ແລ່ນຢູ່ກ່ອນ (terminal ອື່ນ):
#    cd ../backend && pnpm start:dev

# 3. run + hot reload
flutter run
ຕອນ flutter run ແລ່ນຢູ່:

ກົດ r = hot reload (ອັບເດດ UI ໄວ)
ກົດ R = hot restart
ກົດ q = ອອກ
🔧 ຄຳສັ່ງອື່ນທີ່ໃຊ້ເລື້ອຍ

flutter devices          # ເບິ່ງອຸປະກອນທີ່ຕໍ່ຢູ່
flutter run -d e23ddfb9  # run ໃສ່ device id ໃດໜຶ່ງ (ມືຖືເຈົ້າ)
flutter analyze          # ກວດ error ໃນ code
flutter pub get          # ໂຫຼດ dependencies (ຫຼັງແກ້ pubspec.yaml)
flutter clean            # ລ້າງ cache (ຖ້າ build ມີບັນຫາ)
📦 Build APK (ໄຟລ໌ຕິດຕັ້ງ)

flutter build apk --debug     # debug apk (ໄວ, ໃຊ້ທົດສອບ)
flutter build apk --release   # release apk (ສຳລັບແຈກຈິງ)
# ໄຟລ໌ອອກທີ່: build/app/outputs/flutter-apk/app-debug.apk
ຕິດຕັ້ງ apk ໃສ່ມືຖື (ຖ້າບໍ່ໃຊ້ flutter run)

adb install -r build/app/outputs/flutter-apk/app-debug.apk
💡 ວິທີ່ໄວທີ່ສຸດ ຕອນພັດທະນາ: ເປີດ 2 terminal —

cd backend && pnpm start:dev (backend)
cd mobile && adb reverse tcp:3000 tcp:3000 && flutter run (app)
ແລ້ວແກ້ code → ກົດ r ໃນ terminal ຂອງ flutter run → ເຫັນຜົນທັນທີ.

ຢາກໃຫ້ຂ້ອຍຊ່ວຍ run ໃຫ້ ຫຼື ມີ error ຕອນ run ບໍ? 🚀