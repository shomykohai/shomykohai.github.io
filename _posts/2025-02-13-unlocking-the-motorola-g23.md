---
layout: post
author: Shomy
title: "Unlocking the Motorola G23"
date: 2025-02-13
categories: posts
tags:
- Android Modding
- Bootloader Unlocking
---

Unlocking the Motorola G23 was not an easy task, but we finally did it! 

In this article, I'll explain how I and a team of enthusiasts managed to unlock the bootloader of the Motorola G23, a device that was previously thought to be unlockable.

## The Motorola G23

The Motorola Moto G23 is a smartphone that was released in January 2023.
Out of the box, the device might seem quite clean and minimal, but that all changed when Android 14 came.

I've been looking for to mod the device when Android 13 was still the latest version, but I couldn't find any information on XDA developers, or any other forums.

So I started my own research.

## The first tries

I started by looking for known ways to unlock previous Motorola phones, starting by G22.<br>

Here, I found out about how [mtkclient](https://github.com/bkerler/mtkclient) was used to unlock the bootloader on G22, so I thought giving it a try.<br>
Unfortunately, the G23 BROM was blocked compared to G22, and only the preloader port was accessible.<br>
This wouldn't be a problem, if only the preloader wasn't patched! Crash DA wasn't available, and the device would just reboot into preloader mode.<br><br>

Just like that, I was stuck.<br><br>

So, I tried extracting the firmware from the official rescue software, RSA, and I was able to find both the stock firmware and the flash tool, the latter being an encrypted zip file.<br>
In the firmware I found a file named `MT6768_USER.bin`, which seemed to work at some extent.I tried using mtkclient's `da unlock` command, and it failed.<br>
I knew RSA was able to flash stock firmware somehow, so tried getting the flash tool RSA used, and I was able to get the Flash Tool unencrypted by making RSA start a rescue, in which the tool had to be extracted beforehand.<br>
In the Flash Tool, I've found another Download Agent, which I used with mtkclient, and this one booted too! Unfortunately, it seemed like the DA wasn't able to read partitions or flash anything.<br><br>

Some months later, thanks to [@DiabloSat](https://github.com/progzone122), we were able to use this DA file to dump the firmware.<br><br>

These tries were all made in early 2024, and I decided to just not bother with the device anymore, until Android 14 came.

## The Helio G85 telegram group

In late 2024, I once again tried to look up for an unlocking method for the device, because of how laggy the device became with Android 14.
I searched for `penangf` (Moto G23 codename) on GitHub, and I found that someone was able to extract the Flash Tool from RSA, the same way I did.<br><br>

I looked at the Flash Tool files once again, and thought about how I could use it to unlock the bootloader.<br>
Unfortunately, as already said before, the Download Agent was not able to read partitions or flash anything that wasn't signed.<br>
I decided to look up on telegram, and I found a group where people were discussing on ways to unlock the bootloader, and found out that [DiabloSat](https://github.com/progzone122), the same person which uploaded the flash tool on GitHub, was on the group.<br><br>

For some time, I occasionally checked the group to see if someone managed to unlock the bootloader. Unfortunately, no one did.<br><br>

Near Novemeber 2024, I decided to open an issue on the Flash Tool repository, after I've found out we could use other flash tools to flash the firmware.<br><br>

Unfortunately, this concluded nothing, and I was stuck once again, and decided to once again occasionally check the group.

## The testpoints

Around December 2024, I found another repository popup with the schematics for the phone, and I found out that the device had testpoints, which could be used to force BROM.

I decided to open an issue on the schematics repository, and I was able to get in touch with the DiabloSat, who uploaded the schematics.

From that day to until February 2025, we decided to team up to finally unlock the bootloader of the phone.<br>
We shared ideas, possible testpoints and more, but unfortunately, we couldn't find a way to force BROM.

We started to document all the discoveries we made, which can be accessed [here](https://penangf.fuckyoumoto.xyz).

In the meantime, I decided to decompile the bootloader and the preloader, to find out how the device worked, and I found out that the preloader should be able to.

```c
#define KPDL1 KPCOL0 // 0
#define KPDL2 PWRKEY_HW // 8
#define KPDL3 HOMEKEY_RST // 17

bool are_dl_keys_pressed()
{
    if(mtk_detect_key(KPDL1) && mtk_detect_key(KPDL2) && mtk_detect_key(KPDL3))
    {
        pr_debug("dl keys are pressed\n");
        return true;
    }

    return false;
}
```

```c
#define MODULE "[PLFM]"

void platform_emergency_download(int timeout)
{
    pr_debug("%S emergency download mode(timeout=%d)\n", MODULE, timeout);

    platform_safe_mode(1, timeout);

    mtk_arch_reset(0);

    while(1);
}
```

One of these keys is the KPCOL0 testpoint, which was tested thanks to DiabloSat.

![Moto G23 Testpoints](/media/posts/2025/penangf_mb_front_tp.png)
_Photo by DiabloSat_

We were able to find the logs in the `expdb` partition, in which the phone seemed to indeed call the `platform_emergency_download` function, but unfortunately, the device would just reboot into preloader mode.

## Decompiling the bootloader

While DiabloSat was testing the testpoints and trying to force mtkclient to send the device to BROM, I decided to decompile **lk.img**, the bootloader of the device.<br>

There I found something really interesting, our device was indeed able to be unlocked, compared to what official sources said.<br>

The problem was, the device needed a key to be unlocked.<br>
We were blocked again.<br>

But, one day Diablo found out about two important commands for us: `fastboot oem get_key` and `fastboot oem key <KEY>`.<br>

We had it, we thought.<br>
The key from the first command, unfortunately, was not the one we were looking for.<br>
Or so, we thought at first.<br><br>

I tried looking back at LK, and I found out the function that generates the key, which used a SHA256, and for a few days, we tried to reverse engineer the key, but we couldn't.<br>

Then for another week or two, we focused on trying again to force BROM, and Diablo contacted [R0rt1z2](https://github.com/R0rt1z2), who apparently had experience with MediaTek devices.<br>

Roger bought a Moto G13, and he tried to try some of the testpoints we found, but unfortunately, BROM was apparently blocked by efuse, and unfortunately, his device broke.

We thought about exploiting a buffer overflow, but then..<br><br>

I decided to finally reverse engineer how the key was generated from the phone.

```c
#define UNLOCK_KEY_SIZE 32
#define SOC_ID "0123456789ABCDEF0123456789ABCDEF" // Generic SOC ID

int fastboot_flashing_unlock_chk_key(void)
{
    char unlock_key[UNLOCK_KEY_SIZE + 1];
    unsigned char thing_to_hash[65] = {0};
    unsigned char hashed_value[64] = {0};
    int len;

    memset(thing_to_hash, 0, 65);

    len = strlen(SOC_ID);
    if (len == UNLOCK_KEY_SIZE) {
        fastboot_info(SOC_ID);
        mtk_memcpy(thing_to_hash, SOC_ID, UNLOCK_KEY_SIZE);
        mtk_memcpy(thing_to_hash + 32, thing_to_hash, 32);

        fastboot_info("start fastboot unlock");
        fastboot_info(fb_unlock_key_str);

        printf("To hash: %s\n", thing_to_hash);

        // This calculates the hash of the SOC_ID and stores it in hashed_value
        sha256(thing_to_hash, 64, hashed_value);
        

        printf("Hash is: ");
        for (int i = 0; i < 32; i++) printf("%02x", hashed_value[i]);

        printf("\n");

        len = compare_strings_until_length(fb_unlock_key_str, (char*)hashed_value, UNLOCK_KEY_SIZE);
        if (len != 0) {
            fastboot_fail("Unlock key code is incorrect!");
            return 0x7001;
        }

        fastboot_info("Unlock Success");
        len = 0;
    }
    else {
        len = 0x7000;
        fastboot_fail("Unlock key length is incorrect!");
    }

    return len;
}
```

<img src="/media/posts/2025/unlock_key_algorithm.png" style="width: 50%; heigth: 50%"/>

And just like that, I made a python script and asked the other members of the team to try it out.

```python

def oem_keygen(key: str) -> str:
    to_hash: str = key * 2

    hash: str = sha256(to_hash.encode()).hexdigest()

    print("Unlock key: %s" % (hash[:32]))
    return hash
```

```bash
➜  fuckyoumoto git:(main) ✗ python oem_keygen.py 061A757D042B2A378D9761E60C9D3FBC
Unlock key: 87f3aef774eb3edbcdef39e2e94d05c9

➜  fuckyoumoto git:(main) ✗ fastboot oem key 87f3aef774eb3edbcdef39e2e94d05c9 
(bootloader) open fastboot unlock
OKAY [  0.000s]
Finished. Total time: 0.000s
➜  fuckyoumoto git:(main) ✗ fastboot flashing unlock
(bootloader) Start unlock flow

(bootloader) 061A757D042B2A378D9761E60C9D3FBC
(bootloader) start fastboot unlock
(bootloader) 87f3aef774eb3edbcdef39e2e94d05c9
(bootloader) Unlock Success
(bootloader) fastboot unlock success
OKAY [  5.320s]
Finished. Total time: 5.320s
➜  fuckyoumoto git:(main) ✗ fastboot oem lks
(bootloader) lks = 0
OKAY [  0.005s]
Finished. Total time: 0.005s
```

> We did it.<br>
> The bootloader got unlocked!

## Moving forward

We were able to unlock the bootloader of the Motorola G23, and thanks to [Roger](https://github.com/R0rt1z2), who got another G13 with UART too, we were able to confirm that the same method worked on the G13.

The days later were spent on trying to find a way to boot TWRP (thanks [@GitFASTBOOT](https://github.com/GitFASTBOOT) for making it), and testing GSIs.<br>

<img src="/media/posts/2025/twrp_mainscreen.jpg" alt="TWRP main screen" style="width: 30%; heigth: 30%"/>


The plans for the future are to try to port LineageOS, and spread the word about the device, and how it can be unlocked.

## Chouchou (Custom bootloader)

Now that the phone got unlocked, Roger decided to build a payload to inject code into LK, to be able to add new features to fastboot.

![chouchou injection](/media/posts/2025/chouchou_injection.png)

This payload protects the device from being relocked and blocks flashing of protected partitions that might hard brick the device.


## Video Guide

<iframe height="315" src="https://www.youtube-nocookie.com/embed/3fHfiqM7UUg" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Conclusion

We finally were able to unlock the bootloader of the phone, after 2 years from its release date, finally making the device fully ours.

Special thanks to DiabloSat, R0rt1z2 (Roger) for helping me out with this project, GitFASTBOOT for making TWRP, and everyone else who helped us out.<br><br>



Check [our documentation](https://penangf.fuckyoumoto.xyz) for more information on the device!
