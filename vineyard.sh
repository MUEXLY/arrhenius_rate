#!/usr/bin/bash

# get config file name from command line and define a quick function for accessing its keys
config_file_name=$1
cfg() {
    jq -r $1 ${config_file_name}
}

# create file with lines that define pair_style
pair_style=$(cfg '.pair_style')
pair_coeff=$(cfg '.pair_coeff')
potential_file=$(cfg '.potential_file')
echo "pair_style ${pair_style}" > ${potential_file}
echo "pair_coeff ${pair_coeff}" >> ${potential_file}

# set some variables from config file, do neb run with those variables
lmp=$(cfg '.exec')
np=$(cfg '.np')
neb_input=$(cfg '.neb_input')
neb_log=$(cfg '.neb_log')
mpirun -np ${np} ${lmp} -partition ${np}x1 -in ${neb_input} \
    -pl none \
    -ps none \
    -log ${neb_log} \
    -var potential_file ${potential_file}

# set some more variables necessary to perform finite-differencing
etol=$(cfg '.etol')
ftol=$(cfg '.ftol')
maxsteps=$(cfg '.maxsteps')
dx=$(cfg '.dx')
dynmat_init=$(cfg '.dynmat_init')
dynmat_saddle=$(cfg '.dynmat_saddle')

# grab the last line from the neb log file with reaction coordinate info and store data in array
last_line=$(tail -n 1 <(tr -s " " < ${neb_log}))
readarray -d " " -t array <<< "$last_line"

# trim off the number of extra columns
nextracols=$(cfg '.nextracols')
sliced=("${array[@]:nextracols}")

# store reaction energies in array, energies are in even indices
energies=()
for ((i=0; i<${#sliced[@]}; i++)); do
    if ((i % 2 != 0)); then
        energies+=("${sliced[$i]}")
    fi
done

# find the saddle point index, i.e. the index with the largest energy
max_index=0
max_value=${energies[0]}
for ((i=0; i<${#energies[@]}; i++)); do
    if (( $(echo "${energies[i]} > $max_value" |bc -l) )); then
        max_index=$i
        max_value=${energies[i]}
    fi
done

# LAMMPS starts indexing from 1
saddle=$((max_index+1))

# run dynamical matrix calculations for initial and saddle
mpirun -np ${np} ${lmp} -in in.dynmat \
    -var initial 1 \
    -var saddle ${saddle} \
    -var potential_file ${potential_file} \
    -var etol ${etol} \
    -var ftol ${ftol} \
    -var maxsteps ${maxsteps} \
    -var dx ${dx} \
    -var dynmat_init ${dynmat_init} \
    -var dynmat_saddle ${dynmat_saddle}

# zip the files
gzip --force ${dynmat_init}
gzip --force ${dynmat_saddle}

# calculate prefactor and print it to file
prefactor=$(cfg '.prefactor')
python prefactor.py ${dynmat_init}.gz ${dynmat_saddle}.gz > ${prefactor}
