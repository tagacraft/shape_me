# minetest mod subnodes_registerer
Hello all, this is my first mod for minetest AND my first GitHub steps, so thank you for your indulgence :)

Aim of this mod "subnodes_registerer" :
=======================================

Image you are playing minetest, you see an interesting block, default:mese_block for example, 
and you would like to use it as stair, but it is not yet implemented by the mod 'stairs' whitch 
is installed on your solo world (or the server) you are on.

Just use the intended tool provided by subnodes_registerer to hit the default:mese_block in-game
and subnodes_registerer will do it for you !

that's it : subnodes_registerer enable in-game player to designate a block to be processed by some 
installed mod to derivate it into some sub-blocks like stairs, slopes, microblocks, columns, etc.
while the modder (me) do not have to write any new line of code to integrate some mod unknown for the moment.

As we know blocks can be registered only at load time, subnodes_registerer will fill needed data into a file
in order to finish it's work at next server restart.

Scenario of the mod :
=====================

  - we will speak about "any_mod", a theorical mod that do something with block;
  - any_mod have a function named registerfunc(params) which an external mod (e.g. subnodes_registerer)
  can call to let any_mod doing it's work;
  - any_mod should be able to let subnodes_registerer know it's existence and the right registerfunc(params)
  to call, so any_mod's author should implement such a calling to a subnodes_registerer function :
  let's name it subnodes_registerer:register_me(needed_params).
  this scenario implies any_mod/depends.txt file contain a "subnodes_registerer?" line;
  - subnodes_registerer, at load time, load datas about mods to call, blocks to process and then call 
  the any_mod:registerfunc(params):
  this scenario implies subnodes_registerer/depends.txt file to contain a "any_mod?" line:
  
      there is a circular reference we must work around.
      ==================================================
      
      - any_mod don't call subnodes_registerer, but a coming soon mod 'subnodes_linker' which will perform
      populating data files for subnodes_registerer to know the existence of any_mod:registerfunc(params) and
      modifying subnodes_registerer/depends.txt file by adding a "any_mod?" line.
      - then the circular reference doesn't exist anymore and subnode_registerer can call any_mod's function.
      
  For pre-existing mods that are written with no call to subnodes_linker, we must let an accredited player to do 
  this job in-game : making a link beetwen any_mod and subnodes_registerer.
  waiting for this step, the first release of subnodes_registerer will have a minimal data file containing links to
  the 3 mods stairs, moreblocks (for circular saw from stairsplus) and columnia.
  
  So, at load time :
    subnodes_registerer load files about mods to call and blocks to process;
    for each block to process, subnodes_registerer call each mod's :registerfunc(params).

  at run-time :
    regarding to privileges granted, the player can :
    "user" player :
    - punch a node with the intended tool then subnodes_registerer calculates what can be done with this punched_thing,
      and show a summary;
    - confirm or cancel the summary, then subnodes_registerer prepare itself for work to do at next server restart;
    "controler" player :
    - same as "user", plus : accept or reject the work prepared by "user" players;
    "admin" player :
    - same as above, plus : can make link beetwen any_mod and subnodes_registerer;
    - can access all the options that may appear during developpment :)
    

What is done :
==============



TODO list :
===========
