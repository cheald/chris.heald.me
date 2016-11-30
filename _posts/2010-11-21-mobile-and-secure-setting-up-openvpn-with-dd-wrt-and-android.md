---
layout: post
title: Mobile and secure - setting up OpenVPN with DD-WRT and Android
categories:
- How-To
- Security
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  _syntaxhighlighter_encoded: '1'
  _wp_old_slug: ''
  dsq_thread_id: '334764459'
---
So, with all the hubbub about <a href="http://codebutler.github.com/firesheep/">Firesheep</a> lately, and the fact that I'm becoming more mobile in my computing, I figured that it was time for me to get a VPN set up. I didn't want to pay for one, and hey, it turns out that I have all the tools I need to manage my own.

Like any good geek, I'm running a <a href="http://en.wikipedia.org/wiki/Linksys_WRT54G_series">WRT54G</a> with the aftermarket <a href="http://www.dd-wrt.com/site/index">DD-WRT</a> firmware. This is handy, since DD-WRT supports <a href="http://openvpn.net/">OpenVPN</a> right out of the box, so to speak.

I have two targets I'd like to secure: My laptop (running Windows 7) and my Nexus One (running Cyanogen Mod 6.1).

<h2>Setting up OpenVPN on the router</h2>

This is straightforward and easily culled from online resources. Assuming you're running DD-WRTv24, it's dead simple to get up and running. I'll be using a Fedora 11 box for certificate and key generation.

<h3>Install OpenVPN</h3>

    yum install openvpn

<h3>Set up the key generation environment and generate a Certificate Authority cert</h3>

    cd /usr/share/openvpn/easy-rsa/2.0
    source ./vars
    ./clean-all
    ./build-dh
    ./build-ca

Provide whatever information you'd like for the cert, but set the Common Name to something usable, like "OpenVPN CA".

<h3>Generate a certificate and key for your OpenVPN server (DD-WRT, in this case)</h3>

    ./build-key-server server

Provide whatever information you'd like for the cert, but set the Common Name to something usable, like "OpenVPN Server".

<h3>Install the certificates and keys to the OpenVPN server</h3>

1. In your DD-WRT install, go to `Services -> VPN`
1. Set `OpenVPN Daemon -> Start OpenVPN` to "enable"
1. Set `Start Type` to "WAN Up"
1. Copy the contents of your `ca.crt` into "Public Server Cert"
1. Copy the key bits of your `server.crt` into Public Client Cert. It looks something like this:

        -----BEGIN CERTIFICATE-----
        MIIDnjCCAwegAwIBAgIBATANBgkqhkiG9w0BAQUFADB0MQswCQYDVQQGEwJVUzEL
        MAkGA1UECBMCQVoxEDAOBgNVBAcTB1Bob2VuaXgxEDAOBgNVBAoTB09wZW5WUE4x
        ...
        i1fFhoNuFxC2z3D+Otg1SuBvA6v/zENRMTPduAr163G105brjN2BiAyEcTjxsqfl
        c6H57iwLaoyxxiJZVYx2WBYX0+13qf/jPoCd/IkCDnOv64R+8z4stgQlAUmNlNLU
        J/8BjCn+3FmA7uosamYi3bsW
        -----END CERTIFICATE-----

  Be sure to include the BEGIN and END lines.
1. Copy the contents of `server.key` into "Private Client Key"
1. Copy the contents of `dh1024.pem` into "DH PEM"
1. Copy something like the following into "OpenVPN config":

        push "route 192.168.1.0 255.255.255.0"
        server 192.168.66.0 255.255.255.0

        dev tun0
        proto udp
        keepalive 10 120
        dh /tmp/openvpn/dh.pem
        ca /tmp/openvpn/ca.crt
        cert /tmp/openvpn/cert.pem
        key /tmp/openvpn/key.pem
        management localhost 5001

  The "push" line should be the subnet of your local network ("192.168.1.0 255.255.255.0" means "all addresses between 192.168.1.1 and 192.168.1.255), and the "server" line should be the subnet of your new virtual network. In most cases, these defaults should work just fine.
1. Click "Save"
1. Go to Administration -> Commands
1. Enter the following:

        iptables -I INPUT 1 -p udp --dport 1194 -j ACCEPT
        iptables -I FORWARD 1 --source 192.168.66.0/24 -j ACCEPT

        iptables -I FORWARD -i br0 -o tun0 -j ACCEPT
        iptables -I FORWARD -i tun0 -o br0 -j ACCEPT
1. Click `Save Firewall`
1. Go to Administration -> Management, then click `Reboot Router`

Now, it's time to configure our clients.

<h3>Generate certificates for the laptop and phone</h3>

    ./build-key laptop
    ./build-key phone

<h3>Package relevant certificates into a .p12 file for the phone</h3>
Android can import .p12 files, which consist of a root certificate, client certificate, and client key. We already have those three, so we just need to package them up.

    cd /usr/share/openvpn/easy-rsa/2.0/keys
    openssl pkcs12 -export -in phone.crt -inkey phone.key -certfile ca.crt -name "Phone VPN" -out phone.p12

Once that's done, copy the .p12 file to the root of your phone's SD card. To install it, you're going to go to `Settings -> Location and Security -> Install from SD Card`. Just follow the steps - the import should find your .p12 file and import your certificates. You'll be asked to create a certificate storage password if you haven't imported any certificates before. Do so.

<h3>Configure the phone VPN</h3>

1. Go to `Settings -> Wireless & Networks -> VPN Settings`
1. Click `Add VPN`
1. Select `Add OpenVPN VPN`
1. Set a name for your network (I chose "home")
1. Under `Set VPN Server` you need to set your router's WAN address. The easiest way to do this is to use something like <a href="http://www.dyndns.com/">DynDNS</a> to get a host name to map to your IP address, but this is a topic for another post.
1. Set the CA and user certificates to the certificates you just imported
1. Hit the back button and connect! Your phone should now be using your VPN, and you can connect to public wifi with it with impunity.

<h3>Configuring the Windows VPN</h3>

1. Grab the client download from <a href="http://openvpn.net/">openvpn.net</a> and install it.
1. Once installed, open a text editor. We have to create our VPN config file manually, but it's not much of an issue to do so.
1. Create a file in `C:\Program Files (X86)\OpenVPN\config` (or equivalent) called `home.ovpn`. In it, paste the following:

        remote xxx.homedns.org 1194
        client
        remote-cert-tls server
        dev tun0
        proto udp
        resolv-retry infinite
        nobind
        persist-key
        persist-tun
        float
        route-delay 30
        ca ca.crt
        cert laptop.crt
        key laptop.key

Save it. Be sure to replace the hostname in the first line with your home hostname or IP.

1. You probably noticed the certificate key references in the config file. Copy the laptop.crt, laptop.key, and ca.crt files you generated earlier into the same directory as the home.ovpn file
1. Start the OpenVPN GUI. I had to run it as an administrator to get it to work properly.
1. Double-click the tray icon and hit Connect. After a few seconds, your machine should be connected to your VPN, and the systray will notify you of your new virtual IP.

Congrats, that's all there is to it! You can now route all your mobile traffic securely through your home connection, and rest assured that it's safe from prying eyes. In my case, I get some extra benefits like being able to access my development servers and Samba shares without any extra hassle - definitely a nice perk!

Enjoy, and be secure!
