##
#
#  Copyright (c) 2011 - 2022, ARM Limited. All rights reserved.
#  Copyright (c) 2014, Linaro Limited. All rights reserved.
#  Copyright (c) 2015 - 2020, Intel Corporation. All rights reserved.
#  Copyright (c) 2018, Bingxing Wang. All rights reserved.
#  Copyright (c) Microsoft Corporation.
#
#  SPDX-License-Identifier: BSD-2-Clause-Patent
#
##

################################################################################
#
# Defines Section - statements that will be processed to create a Makefile.
#
################################################################################
[Defines]
  PLATFORM_NAME                  = tb710fu
  PLATFORM_GUID                  = 5B0C9E5A-7D1F-4E52-9A0B-71F0C0FEE710
  PLATFORM_VERSION               = 0.1
  DSC_SPECIFICATION              = 0x00010005
  OUTPUT_DIRECTORY               = Build/tb710fuPkg
  SUPPORTED_ARCHITECTURES        = AARCH64
  BUILD_TARGETS                  = RELEASE|DEBUG
  SKUID_IDENTIFIER               = DEFAULT
  FLASH_DEFINITION               = tb710fuPkg/tb710fu.fdf
  USE_CUSTOM_DISPLAY_DRIVER      = 0

  #
  # 0 = SM8650-AA
  # 1 = SM8650-Q-AA
  # 2 = SM8650-AB
  # 3 = SM8650-Q-AB
  # 4 = SM8650-AC
  #
  # TODO: confirm from /sys/devices/soc0 (scripts/dump-firmware.sh).
  # Mainline TB710FU DT: qcom,msm-id = <696 0x20000>; sold as "SM8650Q".
  SOC_TYPE                       = 3

!include LanaiPkg/LanaiPkg.dsc.inc

[PcdsFixedAtBuild]
  #
  # DDR Memory
  #
  gArmTokenSpaceGuid.PcdSystemMemoryBase|0x80000000

  #
  # UEFI Stack
  #
  gArmPlatformTokenSpaceGuid.PcdCPUCoresStackBase|0xA760D000
  gArmPlatformTokenSpaceGuid.PcdCPUCorePrimaryStackSize|0x40000

  #
  # SMBIOS
  #
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemManufacturer|"Lenovo"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemRetailModel|"TB710FU"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemModel|"Xiaoxin Pad Pro GT"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemRetailSku|"TB710FU"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemBoardModel|"TB710FU"

  #
  # Simple Frame Buffer
  # NT36532 WQHD dual-DSI DSC panel, 3200x2000 native
  # (mainline drivers/gpu/drm/panel/panel-nt36532-wqhd-dual-dsi-dsc.c).
  # TODO: confirm the ABL splash orientation/stride on the device.
  #
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferWidth|3200
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferHeight|2000
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferColorDepth|32

  #
  # Platform PEI
  #
  gQcomPkgTokenSpaceGuid.PcdPlatformType|"LA"

[LibraryClasses]
  #
  # Memory Libraries
  #
  MemoryMapLib|tb710fuPkg/Library/MemoryMapLib/MemoryMapLib.inf

  #
  # QCOM Libraries
  #
  ConfigurationMapLib|tb710fuPkg/Library/ConfigurationMapLib/ConfigurationMapLib.inf

[Components]
  #
  # ACPI Tables
  #
  #tb710fu/AcpiTables.inf
