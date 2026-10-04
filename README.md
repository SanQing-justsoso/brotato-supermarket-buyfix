# Supermarket BuyFix (Brotato mod)

**[中文]** Supermarket 1.0.6(Virtuoso 修复版)的购买崩溃修复分支。游戏 1.1.12.x beta 上点击超市购买按钮会无限递归爆栈导致闪退，本仓库修复了该问题，其余与原版完全一致。
**[English]** A buy-crash-fixed fork of [Supermarket 1.0.6](https://steamcommunity.com/sharedfiles/filedetails/?id=3759466719) (Virtuoso fix) for Brotato. On game 1.1.12.x beta builds, clicking buy in the supermarket UI infinitely recurses and overflows the stack, closing the game instantly. This fork fixes that and changes nothing else.

- Workshop (fixed build): <https://steamcommunity.com/sharedfiles/filedetails/?id=3813377397>
- Original mod: <https://steamcommunity.com/sharedfiles/filedetails/?id=3759466719> (original original: <https://steamcommunity.com/sharedfiles/filedetails/?id=3358630815>)

## The bug / 问题根因

Clicking buy in the supermarket panel ran `general_buy()` in `extensions/ui/menus/shop/shop.gd`:

```gdscript
func general_buy(item_data:ItemParentData):
	_fifth_shopitem.set_shop_item(item_data)
	_fifth_shopitem._on_BuyButton_pressed()
```

`_fifth_shopitem` is a hidden, pooled `ShopItem` card living under an invisible canvas. Calling its `_on_BuyButton_pressed()` directly — instead of letting the real button emit its signal — re-enters the card's own button wiring, which calls the handler again: a single GDScript function re-entering itself through the VM until the C stack overflows. The macOS crash report confirms it: a 3-frame call cycle repeating ~6 times before SIGSEGV, with **no** GDScript error logged (it is legal code, just cyclic).

在超市界面点击购买时，`general_buy()` 会对一张隐藏在不可见画布下的池化 `ShopItem` 卡片**直接调用** `_on_BuyButton_pressed()`。这个调用会重新进入卡片自身的按钮接线，导致该处理函数再次调用自身——单个 GDScript 函数经由虚拟机无限自我重入，直到 C 栈溢出。macOS 崩溃报告实证：3 帧调用循环重复约 6 次后 SIGSEGV，且无任何 GDScript 报错(调用本身合法，只是成环)。

Vanilla shelf buys are unaffected because they reach the same purchase through the real button's signal instead of a direct handler call.
原版货架购买不受影响，因为它们走真实按钮的信号，而非直接调用处理函数。

## The fix / 修复方式

One function, `extensions/ui/menus/shop/shop.gd` — the purchase now calls the container's handler directly, which is the exact entry point the vanilla shelf buy uses:

```gdscript
func general_buy(item_data:ItemParentData):
	_fifth_shopitem.set_shop_item(item_data)
	if is_instance_valid(_shop_items_container):
		_shop_items_container.on_shop_item_buy_button_pressed(_fifth_shopitem)
```

(Plus a one-line ModLoaderLog on shop `_ready` so you can verify the patched build is loaded: `grep "buy-fix" modloader.log`.)

## Compatibility / 兼容性

- Game: Brotato 1.1.15.4 (stable) and 1.1.12.0.beta-3 (beta) — the crash only reproduces on the beta build
- ModLoader: 6.2 / 6.3 (Godot 3)
- Use this **instead of** the original Supermarket, do not run both (both add UI to the shop screen) / 请勿与原版同时启用

## Contents / 目录说明

| Path | What |
|---|---|
| `mods-unpacked/galaxyxin-Supermarket-BuyFix/` | full mod source (fork of 1.0.6, buy fix applied) |
| `Supermarket-BuyFix-1.0.7.zip` | upload-ready zip (same layout as workshop items) |
| `preview.png` | 512x512 workshop preview image |
| `workshop-description.txt` | bilingual Steam-workshop description (BBCode) |
| `apply-fix.sh` | alternative: re-apply the fix to a locally installed original mod |

Rebuild the zip after editing source: `cd mods-unpacked/.. && zip -r Supermarket-BuyFix-1.0.7.zip mods-unpacked`
Upload with Brotato's `GodotWorkshopUtility.app` (zip + preview, workshop ID `3813377397` for updates). The tool needs the Steam client running and the game launched through Steam (or a `steam_appid.txt` containing `1942280` next to the tool binary), otherwise all UGC calls fail with `SteamUGC() == null`.

## Credits / 致谢

Original mod: **duyang97 / ercjul / Virtuoso** (Supermarket 1.0.6). Buy fix & fork publishing: **galaxyxin** ([@SanQing-justsoso](https://github.com/SanQing-justsoso)). No upstream repository exists (Steam-workshop-only distribution); if the original author opens one, this diff is offered upstream as-is.
