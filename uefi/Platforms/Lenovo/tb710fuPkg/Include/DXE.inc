  INF MdeModulePkg/Core/Dxe/DxeMain.inf
  INF MdeModulePkg/Universal/PCD/Dxe/Pcd.inf

!if $(TB710FU_VENDOR_HW) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/EnvDxe/EnvDxeEnhanced.inf
!endif

  INF MdeModulePkg/Universal/ReportStatusCodeRouter/RuntimeDxe/ReportStatusCodeRouterRuntimeDxe.inf
  INF MdeModulePkg/Universal/StatusCodeHandler/RuntimeDxe/StatusCodeHandlerRuntimeDxe.inf
  INF ArmPkg/Drivers/CpuDxe/CpuDxe.inf
  INF MdeModulePkg/Core/RuntimeDxe/RuntimeDxe.inf
  INF MdeModulePkg/Universal/SecurityStubDxe/SecurityStubDxe.inf

!if $(TB710FU_VENDOR_HW) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/ShmBridgeDxe/ShmBridgeDxeLA.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/TzDxe/ScmDxeCompat.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/TzDxe/TzDxeLA.inf
!endif

  INF MdeModulePkg/Universal/WatchdogTimerDxe/WatchdogTimer.inf
  INF MdeModulePkg/Universal/CapsuleRuntimeDxe/CapsuleRuntimeDxe.inf
  INF MdeModulePkg/Universal/Variable/RuntimeDxe/VariableRuntimeDxe.inf
  INF EmbeddedPkg/EmbeddedMonotonicCounter/EmbeddedMonotonicCounter.inf
  INF MdeModulePkg/Universal/ResetSystemRuntimeDxe/ResetSystemRuntimeDxe.inf
  INF EmbeddedPkg/RealTimeClockRuntimeDxe/RealTimeClockRuntimeDxe.inf
  INF EmbeddedPkg/MetronomeDxe/MetronomeDxe.inf
  INF MdeModulePkg/Universal/HiiDatabaseDxe/HiiDatabaseDxe.inf
  INF ArmPkg/Drivers/ArmGicDxe/ArmGicDxe.inf
  INF ArmPkg/Drivers/TimerDxe/TimerDxe.inf

!if $(TB710FU_VENDOR_HW) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/ChipInfoDxe/ChipInfoDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/PlatformInfoDxe/PlatformInfoDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/DALSYSDxe/DALSYSDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/HWIODxe/HWIODxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/TLMMDxe/TLMMDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/PmicDxe/PmicDxeLa.inf
!endif

  INF MdeModulePkg/Universal/DevicePathDxe/DevicePathDxe.inf

  INF MdeModulePkg/Universal/Disk/DiskIoDxe/DiskIoDxe.inf
  INF MdeModulePkg/Universal/Disk/PartitionDxe/PartitionDxe.inf

  INF FatPkg/EnhancedFatDxe/Fat.inf
  INF MdeModulePkg/Universal/Disk/UnicodeCollation/EnglishDxe/EnglishDxe.inf

  # UniXNU: the payload FAT arrives as the ABL initrd; DarwinBoot must live in the
  # firmware volume (a loader read from a volume is refused by image verification).
  INF UniXNUPkg/Driver/UniXNURamDiskDxe/UniXNURamDiskDxe.inf
  INF UniXNUPkg/Driver/UniXNUDxe/UniXNUDxe.inf
  INF DarwinBootPkg/Driver/DarwinBoot.inf
  INF UniXNUPkg/Application/UniXNU/UniXNU.inf

!if $(TB710FU_VENDOR_HW) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/UFSDxe/UFSDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/CmdDbDxe/CmdDbDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/PwrUtilsDxe/PwrUtilsDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/RpmhDxe/RpmhDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/NpaDxe/NpaDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/ULogDxe/ULogDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/VcsDxe/VcsDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/ClockDxe/ClockDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/SPMIDxe/SPMIDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/ICBDxe/ICBDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/SmemDxe/SmemDxe.inf
!endif

  INF MdeModulePkg/Universal/BdsDxe/BdsDxe.inf

!if $(TB710FU_VENDOR_HW) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/RscDxe/RscDxe.inf
!endif

  INF EmbeddedPkg/SimpleTextInOutSerial/SimpleTextInOutSerial.inf
  INF MdeModulePkg/Universal/PrintDxe/PrintDxe.inf
  INF MdeModulePkg/Universal/Console/ConPlatformDxe/ConPlatformDxe.inf
  INF MdeModulePkg/Universal/Console/ConSplitterDxe/ConSplitterDxe.inf
  INF MdeModulePkg/Universal/Console/GraphicsConsoleDxe/GraphicsConsoleDxe.inf

!if $(USE_CUSTOM_DISPLAY_DRIVER) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/CPRDxe/CPRDxe.inf
!endif
!if $(TB710FU_VENDOR_HW) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/GpiDxe/GpiDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/SPIDxe/SPIDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/I2CDxe/I2CDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/SdccDxe/SdccDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/FeatureEnablerDxe/FeatureEnablerDxe.inf
!endif

!if $(USE_CUSTOM_DISPLAY_DRIVER) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/DisplayDxe/DisplayDxe.inf
!else
  INF SiliciumPkg/Drivers/SimpleFbDxe/SimpleFbDxe.inf
!endif

!if $(TB710FU_VENDOR_HW) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/ButtonsDxe/ButtonsDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/ChargerExDxe/ChargerExDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/IPCCDxe/IPCCDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/Smp2pDxe/Smp2pDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/SSRDxe/SSRDxe.inf
  # Crashes
  # INF Binaries/tb710fu/QcomPkg/Drivers/GLinkDxe/GLinkDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/PmicGlinkDxe/PmicGlinkDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/QcomChargerDxe/QcomChargerDxeLA.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/UsbPwrCtrlDxe/UsbPwrCtrlDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/TsensDxe/TsensDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/LimitsDxe/LimitsDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/DDRInfoDxe/DDRInfoDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/XhciPciEmulationDxe/XhciPciEmulationDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/XhciDxe/XhciDxe.inf
!endif

  INF MdeModulePkg/Bus/Usb/UsbBusDxe/UsbBusDxe.inf
  INF MdeModulePkg/Bus/Usb/UsbKbDxe/UsbKbDxe.inf
  INF MdeModulePkg/Bus/Usb/UsbMassStorageDxe/UsbMassStorageDxe.inf

!if $(TB710FU_VENDOR_HW) == 1
  INF Binaries/tb710fu/QcomPkg/Drivers/UsbMsdDxe/UsbMsdDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/UsbDeviceDxe/UsbDeviceDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/UsbInitDxe/UsbInitDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/UCDxe/UCDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/RNGDxe/RngDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/PILDxe/PILDxe.inf
  INF Binaries/tb710fu/QcomPkg/Drivers/PILProxyDxe/PILProxyDxe.inf
!endif
