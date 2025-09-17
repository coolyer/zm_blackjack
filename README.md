# 🎰 Blackjack Machine Script for BO3

**Author:** Coolyer  
**⚠️ Please credit if used.**

---

## 📥 Installation

1. Copy the **_custom** folder into the root of your BO3 directory.  
2. Copy the **share** folder into the root of your BO3 directory.  
3. Place **zm_blackjack.gsc** into your `usermaps/scripts` folder.  
4. Open your map’s GSC and add the required `#using` and `thread` lines (see script comments).  
5. Add your own sound files for the blackjack machine effects.  

---

## 🔧 Integration

### 1. Radiant Setup
- Place one or more `trigger_use` entities where you want slot machines.  
- Set their `targetname` to:  

```c
blackjack_table
```

### 2. Script Setup (GSC)

* Add this line near the top with your other #using lines:
```
#using scripts\zm\zm_blackjack;
```
* In your main setup function (main() or startround()), add:
```
thread zm_blackjack::init_blackjack();
```

### 3. Zone File (.zone)
* Add this line:
```
include,zm_blackjack
```

❤️ Support the Project

If you enjoy this work and want to support future development, consider donating:

[👉 PayPal – Coolyer](https://www.paypal.com/paypalme/coolyer)
