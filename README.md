# Set a time out for back-lit keyboards without a bios timeout. 
This is a personal script to set the timeout of the light of keyboards that doesn't have it.

My Dell laptop had timeout on AC but dell released a bios update that broke that functionality and said they won't fix it. 

there are examples on the services. 

the kbd script is for use on gnome with a wayland session detecting the idle time with the bus.
the X script is to use on xfce. I did not tested on others desktops environments or Windows managers. 

if there was a need for it, I could update the read me and code.

when running on gnome. be sure to pass the right ambient variables on the service as root, otherwise it won't work.
the kbd*_x is to use the service as an user and depends on xprintidle.
