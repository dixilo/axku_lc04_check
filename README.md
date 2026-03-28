# AXKU042 24LC04 MicroBlaze Demo

AXKU042 上の `xcku040-ffva1156-2-i` を対象に、MicroBlaze から自作 I2C コントローラ経由で 24LC04 を 1 バイト単位で読み書きするための最小構成です。

## 含まれているもの

- `rtl/i2c_eeprom_master.v`
  - 24LC04 向けの単純な I2C マスタ
  - シングルバイト read / write に対応
  - write 完了待ちの ACK polling を内蔵
- `rtl/axi_i2c_eeprom_ctrl.v`
  - MicroBlaze から叩くための AXI4-Lite レジスタラッパ
- `rtl/axku_lc04_top.v`
  - 差動 200 MHz クロック入力と BD wrapper をつなぐトップ
- `vivado/create_project.tcl`
  - MicroBlaze / MDM(JTAG UART) / 自作 I2C AXI 周辺をまとめて生成する Vivado TCL
- `vivado/insert_ack_poll_ila.tcl`
  - ACK polling の状態確認用 ILA を挿入する補助 TCL
- `software/src/main.c`
  - UART コンソールから write / read を選ぶ簡単な対話アプリ
- `constraints/axku042_lc04_base.xdc`
  - 共有いただいた XDC を土台にしたピン制約

## レジスタマップ

- `0x00 CONTROL`
  - bit0: `START`
  - bit1: `READ` (`0` で write, `1` で read)
- `0x04 STATUS`
  - bit0: `BUSY`
  - bit1: `ERROR`
  - bit2: `ACK_POLL_ACTIVE`
  - bit3: `ACK_POLL_SEEN`
  - bit4: `LAST_ACK`
  - bit5: `DONE`
- `0x08 ADDR`
  - EEPROM byte address (`0x000` - `0x1FF`)
- `0x0C WDATA`
  - 書き込みデータ
- `0x10 RDATA`
  - 読み出しデータ
- `0x14 DEBUG`
  - FSM 状態と ACK polling 回数の確認用

## 24LC04 アドレス扱い

24LC04 は 512 byte 構成なので、`mem_addr[8]` を I2C デバイスアドレス側へ折り込み、`mem_addr[7:0]` を word address として送る実装にしています。

## ACK polling デバッグ

トップ階層で以下を `mark_debug` しています。

- `dbg_fsm_state`
- `dbg_bit_state`
- `dbg_ack_poll_active`
- `dbg_ack_poll_seen`
- `dbg_last_ack`
- `dbg_ack_poll_count`
- `dbg_scl_sample`
- `dbg_sda_sample`

`vivado/insert_ack_poll_ila.tcl` は、これらの信号を ILA へまとめる想定です。環境によって合成後の net 名が微妙に変わることがあるため、必要なら `get_nets -hier -filter ...` の条件を調整してください。

## Vivado での流れ

1. Vivado Tcl Console で `source /Users/jsuzuki/program/fpga_projects/axku_lc04_check/vivado/create_project.tcl`
2. 生成されたプロジェクトを開く
3. 合成後に必要なら `source /Users/jsuzuki/program/fpga_projects/axku_lc04_check/vivado/insert_ack_poll_ila.tcl`
4. bitstream を生成し、XSA を export
5. Vitis / classic SDK で `software/src/main.c` をアプリ本体としてビルド
6. `stdin` / `stdout` は MDM JTAG UART を想定

## 注意点

- このワークスペースでは `vivado` / `xsct` が使えなかったため、実機ビルドまでは未検証です。
- `vivado/create_project.tcl` の IP Integrator 構成は、Vivado バージョン差でプロパティ名や自動配線要件が変わることがあります。
- I2C は標準モード相当のゆっくりしたクロックを前提にしており、高速化は未実施です。
