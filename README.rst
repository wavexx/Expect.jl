Expect.jl - Expect-like module to drive interactive programs
============================================================

``Expect.jl`` is an Expect-like_ module which can be used to drive interactive,
command-line programs. `Expect` runs a command asynchronously, returning an
handle that can be used to both read *and* write to the command's standard
input/output. It's similar in usage to readandwrite_, though the command is run
under a pseudo-terminal interface, disabling block-buffering and making it
suitable to perform I/O on a a line-by-line basis. ``Expect.jl`` includes
facilities to match the standard-output using regular expressions.

.. contents::

.. warning::

   This is a work-in-progress, the API is subject to change without notice.


Usage
-----

Spawn a program using the ``Expect.ExpectProc`` constructor:

.. code:: julia

  using Expect
  proc = ExpectProc("command")

The command is expected to be a *string* to be interpreted using ``sh -c``.
There is no support to use Julia's `cmd` objects yet.

The handle can be read or written to using the standard I/O functions. In
addition, the following methods are supported:

``sendline(proc, string)``:

  Write `string` to the standard input of the program, followed by a newline.

``expect!(proc, vector)``:

  Read the standard output of the program until one of the strings/regular
  expressions specified in ``vector`` matches. The index of the element that
  matched is returned.

  ``proc.before`` is reset to contain all the standard output before the match.

  ``proc.match`` contains either a string or a match_ object for the element
  that matched.

See ``tests/runtests.jl`` for an usage example.


Authors and Copyright
---------------------

| "Expect.jl" is distributed under the MIT license (see ``LICENSE.rst``).
| Copyright(c) 2014 by wave++ "Yuri D'Elia" <wavexx@thregr.org>.


.. _Expect-like: http://pexpect.sourceforge.net/pexpect.html
.. _readandwrite: http://julia.readthedocs.org/en/latest/stdlib/base/?highlight=readandwrite#Base.readandwrite
.. _match: http://julia.readthedocs.org/en/latest/stdlib/base/?highlight=match#Base.match
