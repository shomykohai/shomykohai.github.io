---
layout: post
author: Shomy
title: "Carbonara: The MediaTek exploit nobody served"
date: 2026-01-11
categories: posts
tags:
- Android Modding
- Bootloader Unlocking
- Reverse Engineering
---
Imagine this:
You walk into a restaurant you only just discovered, the one rumored for serving the best dishes.
It quickly becomes your go-to place for every meal.
One day, something odd happens: a secret dish appears on the menu, *Carbonara*, no price, description, and most importantly, no way to order it.
Only few people know the secret code that makes the chef cook it.

I too wasn't supposed to know, but that's how every story begins, after all.

## How it all began

Around february of 2025, I [unlocked the Motorola G23](https://shomy.is-a.dev/blog/article/unlocking-the-motorola-g23) with the help of some people from the Motorola Helio G85 telegram group.
This was a great victory after almost 2 years from the device release date.

In 2024, the Motorola G24 got released, same SoC, same specs, but totally different bootloader!
After unlocking the G23, we tried to unlock the G24 as well, but the method that worked on it was not applicable on the G24.
For two weeks, we thought it was impossible to unlock.. until

milktoast56 enters the group, asking why a *known GSM tool* could unlock the bootloader, just for it to still claim to be locked.
Me and the other people were surprised and didn't believe it until we saw that the bootloader unlock operation was indeed happening.

We suspected the bootloader was auto relocking itself, so [Roger](https://github.com/R0rt1z2) (see previous blogpost) analyzed the bootloader (lk) in ghidra, to find, guess what, the relock function.

<img src="/media/posts/2026/carbonara/relock_function.png" alt="tinno_commercial_device_force_lock" style="width: 60%;"/>

So, we tested something.
Roger ported chouchou (the lk payload for G23) to G24, patching the relock function. To our surprise, that worked, and the G24 bootloader got unlocked!

Up until august, we relied on the paid tool to perform the unlock operation, until I decided to look deeper into the matter.

## What is going on?

We already tested that mtkclient could not unlock the bootloader, so with Ryszard (another user from the group) we tried to understand what was going on with this tool.

We started with the easiest way: sniffing usb traffic.

Ryszard installed wireshark and started sending me usb traffic from the tool to the device.
For about a week, we thought this tool just had an engineering Download Agent.
I extracted the DA from the usb logs, and made a python script to parse it.
It looked different, but also too similar to the stock one.
I thought that it just had different patches as a consequence of being an engineering DA.

I made another script, to construct back a DA file + header so that mtkclient could then use it.

<img src="/media/posts/2026/carbonara/mtkclient-failing.png" alt="MTKClient fails on uploading the extracted DA" style="width: 70%;"/>

> What??
> The same binary was being sent, yet we get a verification error.

This happens because DA1 verifies the integrity of DA2 before jumping to it, by hashing the received DA2 and comparing it to the expected hash embedded in DA1 itself.
This RoT works when DAA (Download Agent Authorization) is enabled, because this security measure allows only signed DA1 to be loaded.

Something was indeed happening in that tool, so for a few days I studied the XFlash protocol to finally get an answer

### Two boot_to cmd calls?

The boot-to command is invoked to load the second stage DA (DA2) into DRAM, from the first stage DA (DA1), and then jump to it.
This command includes the DA2 size, load address and sha256 hash, so that DA1 can verify the integrity of the DA2 before jumping to it.

<img src="/media/posts/2026/carbonara/wireshark-packet-2.png" alt="Wireshark packet sent by the host" style="width: 70%;"/>

What is this weird string it's sending?
I thought jokingly: "Imagine if it's a sha256 hash"
So, i ran sha256sum on the da2 binary and..


> The hashes match!! So, the tool is patching memory??

But what does the payload it's sending before mean?

<img src="/media/posts/2026/carbonara/wireshark-packet.png" alt="Wireshark packet sent by the host" style="width: 70%;"/>

So, me and Roger studied it, to conclude that all it does is locate the DA2 hash stored in DA1 memory, and overwrite it with the hash of the patched DA2.
This means that when DA1 receives the boot_to command the second time, it will verify the patched DA2 against the patched hash, and the verification will succeed! 

## Replicating the exploit with mtkclient

Now that I understood how the exploit worked, it was time to replicate it to try unlocking the G24 for free™.

I made a quick patch and sent it to the group to test on G24
```python
# xflash_lib.py, line 1226
if self.xsend(self.Cmd.BOOT_TO):
    payload = bytes.fromhex('a4de2200000000002000000000000000')
    if self.xsend(payload):
        if self.status() == 0:
            import hashlib
            da_hash = hashlib.sha256(self.daconfig.da2).digest()
            if self.xsend(da_hash):
                self.status()
                self.info("All good!")
```

<img src="/media/posts/2026/carbonara/mtkclient_unlock.jpg" alt="mtkclient unlocking the G24" style="width: 70%;"/>

> IT WORKED!

So, now everyone could unlock their G24 for free, without relying on paid tools.
But, I wanted to go further.

## Penumbra

With the exploit replicated in mtkclient, I decided to take the opportunity to write my own MediaTek flashing tool.

I’d been wanting to learn Rust for a long time, so I chose this as my first real Rust project.
That's how [Penumbra](https://github.com/shomykohai/penumbra) was born!

What started as a small proof of concept quickly grew into a more complete tool.
At the time of writing, Penumbra has matured quite rapidly and now includes both a TUI and a CLI, called **Antumbra**.

<img src="/media/posts/2026/carbonara/antumbra-tui.png" alt="Antumbra, a TUI powered by Penumbra" style="width: 70%;"/>

The final goal of Penumbra is to be a reliable, free and open source tool for MediaTek devices.

More importantly, every payload and every patch is completely auditable and available for self-recompilation, meaning everyone can easily see and compile Penumbra for themselves without blindly trusting the compiled code.


## So, how does Carbonara actually work?

Carbonara is, at its core, a surprisingly simple exploit.
Everything comes down to **why loading a patched DA2 is possible in the first place**.

On unpatched loaders, the DA2 load address and size are fully user controlled.
This means the host can, in fact, write to any memory region without checks, and free cache invalidation by the DA!

While all known tools implement Carbonara by replacing the DA2 hash to make DA1 accept the next stage, the exploit itself is in fact far more dangerous, allowing to load any arbitrary payload, malicious one included!

This is why all security researchers aware of this exploit decided to keep it private.
However, more and more paid tools started adding this exploit, which resulted in a higher risk of getting infected by rootkits or malware as a consequence.

More details about the exploit can be found in [Penumbra documentation's](https://shomy.is-a.dev/penumbra/Mediatek/Exploits/Carbonara). and the source [code itself](https://github.com/shomykohai/penumbra/blob/main/core/src/exploit/carbonara.rs)

## Conclusions

So, now you know the story of how I (re)discovered Carbonara, the MediaTek exploit nobody served.<br>
I think this story is not just about an exploit or how unlocking bootloader is possible, but also about how many times we trust closed source tools without knowing what they do under the hood, and how important it is to have open source alternatives. 

Special thanks to:
* [Roger (R0rt1z2)](https://github.com/R0rt1z2) for all the help with reverse engineering and testing
* Ryszard for helping with usb traffic analysis
* milktoast56 for bringing up the initial suspicion that led to the discovery
* CXZa for the picture of mtkclient unlocking the G24
* The Motorola Helio G85 telegram group for the support and testing
* [B. Kerler](https://github.com/bkerler) for mtkclient, which helped me understand MTK protocols
