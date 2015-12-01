#!/usr/bin/python3

import sys
import random
import hashlib


def gen_token():
    rnd = ''.join(str(random.randrange(10)) for i in range(7))
    sha256 = hashlib.sha256()
    sha256.update(rnd.encode('utf8'))
    return rnd, sha256.hexdigest()


def main():
    rnd, token = gen_token()
    print('Human-readable token:', rnd, file=sys.stderr)
    print(token)


if __name__ == '__main__':
    main()
