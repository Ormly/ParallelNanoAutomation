#!/bin/bash
cd /nfs/scripts/
git clone git@github.com:Ormly/ParallelNanoAutomation.git automation
git clone git@github.com:Ormly/ParallelNano_Lisa_Beacon.git beacon
git clone git@github.com:Ormly/ParallelNano_Lisa_Beacon_Agent.git beacon_agent
git clone git@github.com:Ormly/ParallelNano_Lisa_Lighthouse.git lighthouse
git clone git@github.com:Ormly/ParallelNano_Lisa_Tempo.git tempo
git clone git@github.com:Ormly/ParallelNanoShowcase.git showcase
chmod 775 -R *