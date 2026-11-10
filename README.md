# UniXNU · TB710FU

Lenovo Xiaoxin Pad Pro GT(TB710FU, SM8650)에 [UniXNU](https://github.com/UniXNU/UniXNU)로 XNU(iPadOS → macOS)를 베어메탈 포팅하는 저장소.

- 하드웨어 값의 기준은 **메인라인 Linux** 트리([SpendyYT/tb710fu-linux](https://github.com/SpendyYT/tb710fu-linux), `sm8650.dtsi` + `sm8650-lenovo-tb710fu.dts`)
- SoC 공통: [loolooc/UniXNU-sm8650-common](https://github.com/loolooc/UniXNU-sm8650-common) (pinned)
- 참고 보드: [houji](https://github.com/lonzzi/UniXNU-houji)(Xiaomi 14, iOS 바탕화면까지 동작), [caihong](https://github.com/Axiang-dev/UniXNU-caihong)(OnePlus Pad Pro, launchd까지), meizu21
- UEFI: Mu-Silicium `LanaiPkg`(SM8650) 위에 OnePlus Ace 5(giulia) 보드 패키지를 기반으로 한 `uefi/Platforms/Lenovo/tb710fuPkg`

## 부팅 체인

```
ABL(잠김, testkey vbmeta) --슬롯 b boot/vendor_boot--> BootShim + Mu-Silicium UEFI --> UniXNU.efi --> DarwinBoot --> XNU(EL1, 자체 빌드) --> IPSW 유저랜드
```

Gunyah가 EL2를 갖고 있어서 XNU는 EL1에서 동작한다. Apple 커널캐시 대신 공개 XNU 소스를 패치해서 빌드한다.

## 진행 단계

| 단계 | 내용 | 상태 |
|---|---|---|
| 0 | 보드 DTS(메인라인에서 생성), SoC 피드, defconfig, `unixnu status` 해석 | ✅ |
| 1 | UEFI: 기기 `uefi_a`에서 추출한 Qualcomm DXE(UEFIReader) + 스톡 메모리 맵(`xbl_config`) + UniXNU/DarwinBoot 통합 | ✅ `SILICIUM_UEFI.fd` 0x300000 빌드 (WSL) |
| 1b | 페이로드(64 MiB FAT) → `vendor_boot`(GKI라 boot에 ramdisk 없음), `boot.img` | ✅ 빌드, 기기 미검증 |
| 2 | XNU 커널 빌드 (GitHub macOS 러너) | ✅ xnu-10063.141.1 + SM8650 패치, iPadOS 17.7.11 커널캐시로 prelink (약 10분) |
| 3 | 슬롯 b로 서명 이미지 부팅 → UEFI 메뉴 → DarwinBoot → 커널 로그 화면 | 🟡 서명·플래시 스크립트 완료, 슬롯 b 덤프와 기기 테스트 대기 |
| 4 | UFS 루트 마운트, launchd | ⏳ |
| 5 | 디스플레이·터치(NT36532 / Novatek SPI) | ⏳ |
| 6 | OS 프로필을 macOS 26.5로 전환 ([macOS-ForSheng](https://github.com/CrossDarwin/macOS-ForSheng) 방식) | ⏳ |

1~5단계는 OS와 무관한 하드웨어 bring-up이라서, SM8650에서 이미 검증된 iPadOS 17(arm64) 프로필로 먼저 진행한다.

## 기기에서 받아야 할 것

Android(LTBox 루팅) 상태에서 받는다. 저장소에는 올리지 않는다.

```bash
scripts/dump-firmware.sh   # uefi/xbl/abl/imagefv/vendor_boot 등 + device-facts.txt
```

- `uefi_a.img` → Mu-Silicium `Binaries/tb710fu` (QcomPkg DXE 드라이버, `uefiplat.cfg`, `SecParti.cfg`)
- `uefiplat.cfg`의 메모리 맵으로 `MemoryMapLib.c` 확정
- `device-facts.txt`의 RAM 크기 → `scripts/gen-board-dts.py --ram-gib`, soc0 serial → ADT 시드(`UNIXNU_UNIQUE_CHIP_ID`)

## 빌드 (WSL)

```bash
# 보드 DTS 다시 생성 (메인라인 DTB 기준)
python3 scripts/gen-board-dts.py ~/tb710fu/tb710fu-linux/arch/arm64/boot/dts/qcom/sm8650-lenovo-tb710fu.dtb \
  --dtc ~/tb710fu/tb710fu-linux/scripts/dtc/dtc > dts/tb710fu.dts
python3 scripts/check-memory-map.py        # UEFI Conv 영역이 no-map 예약 영역과 겹치면 실패

# UniXNU 설정 해석 (UniXNU는 이 저장소 옆 ../UniXNU)
cd ../UniXNU
./unixnu defconfig tb710fu_defconfig -D ../UniXNU-tb710fu
./unixnu fetch
./unixnu status --json
```

커널은 Xcode가 필요해서 GitHub Actions(`build` 워크플로, `workflow_dispatch`)의 macOS 러너에서 빌드한다.

## UEFI·부팅 이미지 빌드 (WSL)

```bash
# Mu-Silicium = UniXNU/uefi-sheng (SEC FDT 핸드오프 포함) + 이 저장소 uefi/ 오버레이
# Binaries/tb710fu = UEFIReader로 uefi_a.img에서 추출 (커밋 안 함)
cd ../UniXNU
./unixnu build firmware --uefi ../uefi-tb710fu
UNIXNU_UNIQUE_CHIP_ID=<soc0 serial hex> ./unixnu build payload
./unixnu vendor_boot --stock ../UniXNU-tb710fu/firmware-dump/vendor_boot_b.img \
  --ramdisk out/tb710fu/*/tb710fu/payload/payload.img --ramdisk-addr 0x2400000
./unixnu bootimg --uefi ../uefi-tb710fu --dtb ../UniXNU-tb710fu/firmware-dump/live-fdt.dtb --ramdisk none
```

## 기기 테스트 (잠긴 부트로더, LTBox 루팅 상태)

잠긴 부트로더는 `fastboot boot`/`flash`를 거부한다. 대신 LTBox와 같은 testkey 경로를 쓴다.
스톡 vbmeta가 AOSP testkey(`2597c218…`)로 서명돼 있어서 다시 서명할 수 있다.

- `boot`: vbmeta에서 testkey로 chain(롤백 위치 3) → testkey 해시 푸터
- `vendor_boot`: vbmeta 안의 해시 descriptor → 다시 계산한 뒤 vbmeta를 testkey로 재서명 (`scripts/avb/avbsign.py rehash`)

Android는 슬롯 a에 그대로 두고 슬롯 b만 바꾼다.

```bash
SLOT=_b scripts/dump-firmware.sh firmware-dump   # vbmeta_b, boot_b, vendor_boot_b 덤프 (읽기만)
# vendor_boot는 vendor_boot_b.img를 --stock으로 다시 만든 뒤
scripts/sign-images.sh firmware-dump images      # boot-signed.img, vbmeta-signed.img
scripts/flash-slot-b.sh --activate images         # 슬롯 b 원본 백업 → 쓰기 → 읽어서 확인 → 슬롯 b 활성화 → 재부팅
```

되돌리기:
- 슬롯 b가 몇 번 부팅에 실패하면 ABL이 슬롯 a(Android)로 돌아간다.
- Android에서 `scripts/restore-slot-b.sh`를 실행하면 슬롯 b가 원본으로 돌아간다.
- Android가 뜨지 않으면 LTBox 고급 도구의 **EDL 파티션 쓰기**로 `firmware-dump/slot-b-backup/*.img`를 되돌린다.

## 부팅 로그 보기 (UART 없음)

| 단계 | 방법 |
|---|---|
| UEFI | DEBUG 빌드라서 Silicium `FrameBufferSerialPortLib`가 UEFI 디버그 로그를 화면에 바로 그린다. 사진으로 남긴다 |
| UniXNU 메뉴 | 메뉴의 `payload: initrd ... fs <n>` 줄. `fs 0`이면 FAT 인식 실패이고, `xnu` 항목이 없으면 페이로드를 못 찾은 것 |
| DarwinBoot → 커널 | 커널로 넘어가기 직전에 화면 위쪽 1/16이 초록색으로 칠해진다 = 커널 진입 직전까지 성공 |
| XNU | `-v`로 커널 로그가 화면에 출력되고, `panic_screen = true`로 패닉 문자열도 화면에 그린다. 사진으로 남긴다 |
| **ramoops (RAM)** | 커널 콘솔 전체를 스톡 Android의 ramoops 콘솔 영역(`0xac340000`)에 pstore 형식으로 기록한다. 패닉이 나면 15초 뒤, 멈추면 120초 뒤 PSCI로 리셋된다. 슬롯 b가 부팅에 몇 번 실패하면 ABL이 슬롯 a로 돌아가고, Android에서 `scripts/read-ramoops.sh`로 읽는다 |
| 저장되는 로그 (UFS) | UFS가 동작한 뒤 `pstoredump`(128 MiB) 파티션에 기록한다 (미구현) |

ramoops를 쓰기 전에 Android에서 한 번 확인한다.

```bash
scripts/read-ramoops.sh --check   # 스톡 ramoops 배치가 0xac340000 / 0x40000 / ecc 16과 맞는지
scripts/read-ramoops.sh --mark    # 커널 로그에 마커를 남기고 재부팅
scripts/read-ramoops.sh           # 재부팅 뒤: console-ramoops-0에 마커가 있으면 리셋 후에도 보존됨
```

슬롯 b가 몇 번 다시 시도되기 때문에, 매 XNU 부팅이 같은 영역에 이어서 기록된다(`=== TB710FU XNU boot ===` 줄로 구분).
링 버퍼가 256 KiB라서 오래된 부분은 덮어써질 수 있다.

## 메모

- DDR이 2 GiB(0x80000000) + 6 GiB(0x880000000, 보안 구멍 포함)로 나뉘어 있다. XNU는 연속 창 하나만 쓰므로 DTS `/memory`는 live FDT에서 가장 긴 연속 구간(0x8c0000000 + 5 GiB)이고, DarwinBoot 창은 2 GiB(`owned_memory_size`).
- 스톡 UEFI 메모리 맵에만 있는 `Display_Demura`(0xA3600000)와 스플래시 버퍼(0xD5100000)를 DTS 예약 영역에 추가했다.

- TB710FU는 rmtfs가 `0xd3000000`(다른 SM8650 보드는 `0xd7c00000`)이라 giulia의 `DXE_Heap`을 `0xD3000000`까지로 줄였다. `check-memory-map.py`가 이 충돌을 잡는다.
- `SOC_TYPE`(SM8650 변형)과 프레임버퍼 방향은 기기 덤프로 확인 필요 (`tb710fu.dsc`의 TODO).
