# ReCS-Docker
Docker scripts to fetch all relevant modules for a 2024+ HL/CS 1.6 Dedicated Server from their sources, build, deploy and run them!


## Current supported modules
- Steam / Original HLDS
- ReHLDS (https://github.com/rehlds/ReHLDS)
- ReGameDLL_CS (https://github.com/rehlds/ReGameDLL_CS)
- Metamod-R (https://github.com/rehlds/Metamod-R)
- ReSemiclip (https://github.com/rehlds/resemiclip)
- ReUnion (https://github.com/rehlds/ReUnion)
- AMXModX (https://github.com/alliedmodders/amxmodx.git)
- ReAPI (https://github.com/rehlds/ReAPI)
- ReVoice Plus (https://github.com/Garey27/revoice-plus)
- HitboxFixer (https://github.com/Garey27/hitbox_fixer)

- also contains many popular amx scripts in their sma source


### Software i would like to include in the future if sources would be released
- ReAimdetector
- WHBlocker from s1lent
- ReRSDetector


## Requirements
docker 


## Build
- `git clone https://github.com/lorbas-dev/ReCS-Docker.git`  
- `cd ReCS-Docker`
- Edit the docker build file if you need specific versions or commits. You can also set ENV variable without touching the file (but you must read the file for variable names ofc :)
- Also you can ofc comment out or add packages
- You can also put all the plugins you need in the cstrike(/addons) folder. They will be merged into the server. (Dont forget to register AMXModX Plugins in cstrike/addons/amxmodx/configs/plugins.ini !)

- `docker build -t hlds_build -f build .`
- This can take a while. Make yourself a coffee and relax. All packages are being downloaded and compiled

- `docker build -t hlds_deploy -f deploy .`
- This copies all the files to the location they belong
- also copys your local cstrike folder containing all mods, scripts and plugins to the docker container
- compiles all .sma plugins in cstrike/addons/amxmodx/scripting and puts them in ../plugins


## Run
- `docker run -it --name="hlds" -p 27015:27015 -p 27015:27015/udp hlds_deploy`


## Disclaimer, Security & Usecases
I have no idea if this setup is safe on the internet and i dont recommend using it for a live gameserver  
This project is intended to be used as a development and testing platform only!  
I dont take any responsibility for what this software can or cant do


## Credits
- ReHLDS Team
- s1lent
- dreamstalker
- Garey27
- Sergey Shorokhov
- theAsmodai
- Alliedmodders
- all original Modders & everyone i forgot :)

For their original idea of a docker rehlds build:
- BLSAlin (https://github.com/BLSAlin/rehlds-cstrike)
- artkirienko (https://github.com/artkirienko/hlds-docker-dproto)