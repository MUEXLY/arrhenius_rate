#!/usr/bin/python

"""
script for calculating the Vineyard prefactor from dynamical matrices
"""

import sys

import numpy as np
from numpy.typing import NDArray


def get_nonzero_eigvals(file_name: str) -> NDArray[float]:

    """
    get the non-zero eigenvalues from text file
    """

    dynmat = np.loadtxt(file_name)
    dynlen = int(3 * np.sqrt(len(dynmat) / 3))
    dynmat = dynmat.reshape((dynlen, dynlen))
    eigvals, _ = np.linalg.eig(dynmat)

    return eigvals[eigvals != 0]


def main():

    # grab eigenvalues from text files specified in command line
    initial_eigvals = get_nonzero_eigvals(sys.argv[1])
    saddle_eigvals = get_nonzero_eigvals(sys.argv[2])

    # make sure there are the same number of non-zero eigenvalues for both states
    assert initial_eigvals.shape == saddle_eigvals.shape

    # make sure there is one negative eigenvalue at saddle, and none at initial
    assert np.sum(saddle_eigvals < 0) == 1
    assert np.sum(initial_eigvals < 0) == 0

    # calculate prefactor and print it to stdout
    prefactor = np.exp(
        0.5
        * (
            np.sum(np.log(initial_eigvals))
            - np.sum(np.log(saddle_eigvals[saddle_eigvals > 0]))
        )
    )

    print("# Vineyard prefactor in THz")
    print(prefactor)


if __name__ == "__main__":

    main()
