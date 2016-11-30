---
layout: post
title: Enabling brightness controls on an HP Envy 17 under Fedora 16
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '470670577'
---
I've recently set up Fedora 16 on my laptop, and all has been smooth, save for the brightness switches. The on-screen display would show up when I used the fn-F2/fn-F3 key combinations, but the brightness just wouldn't change. Additionally, the brightness was stuck at the lowest level.

Turns out there's a pretty easy fix in the form of a couple of module parameters:

In `/etc/defaults/grub`, add the following kernel parameters:

    video.brightness_switch_enabled=1 video.use_bios_initial_backlight=0

(You may also want to add `radeon.modeset=1` and `acpi_osi=Linux` for this particular machine, but they aren't related to the brightness fix.)

Then update your grub2 config:

    grub2-mkconfig > /boot/grub2/grub.cfg

Reboot, and your brightness controls should work as expected. The brightness slider in GNOME still doesn't work, but I'm content with hardware brightness controls over no brightness controls.

