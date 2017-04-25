Expect.jl: Synchronous communication with interactive programs
==============================================================

.. contents::

``Expect.jl`` allows to spawn interactive applications and control them by
communicating through their standard input/output streams.

``Expect.jl`` is similar to D. Libes's Expect_ and many other Expect-like
modules. It can be used to automate interactive applications such as shells,
perform software testing or drive test harnesses easily.

.. warning::

   This is a work-in-progress, the API is subject to change without notice.
   Suggestions about API design are highly appreciated.


Introduction
------------

The idea behind Expect is simple: commands are spawned with their I/O
descriptors attached to the current process. You write to the command's
standard input, then you wait for a set of known replies from it's output.

If the program you're communicating with was already meant to be controlled
through a serial protocol, then using readandwrite_ directly is recommended as
it avoids some overhead when spawning the process.

Expect differs from ``readandwrite`` in three major ways:

- Commands are spawned under a pseudo-TTY interface, forcing libc-based
  programs to flush their output buffer at each line.
- Reading is performed for you until a set of possible conditions is met.
- Reading raises an ExpectTimeout exception when it blocks for longer than the
  requested threshold.


Basic usage
-----------

Using ``ftp`` to retrieve a remote file list:

.. code:: jlcon

   julia> # Start a new process
   julia> using Expect;
   julia> proc = ExpectProc(`ftp ftp.scene.org`, 16);
   julia> # Wait for the prompt
   julia> expect!(proc, "> ");
   julia> # Send "ls" and wait for prompt
   julia> println(proc, "ls");
   julia> expect!(proc, "> ");
   julia> # Collect all the output since the last prompt
   julia> list = proc.before;
   julia> println(list);
   drwxrwsr-x  11 redhound ftpadm       4096 Mar  2 20:57 incoming
   drwx------   2 redhound ftpadm      16384 Feb 24 12:58 lost+found
   -rw-r--r--   1 redhound ftpadm   16060223 Mar 22 01:15 ls-lR
   -rw-r--r--   1 redhound ftpadm    2723919 Mar 22 01:15 ls-lR.gz
   drwxrwsr-x  12 redhound ftpadm       4096 Nov 26  2013 mirrors
   drwxrwsr-x   8 redhound ftpadm       4096 Mar  4 18:25 pub
   -rw-r--r--   1 redhound ftpadm        547 Nov  9  2013 welcome.msg

Some highlights about the example:

- The first argument to ExpectProc_ is just a regular Cmd_ object.
- You don't have to worry about buffering.
- An ``ExpectProc`` handle can be read or written to using the standard I/O
  functions such as ``readbytes!`` or ``println``.
- ``proc.before`` contains all the command's output *since the last expect!
  match* (excluding the match itself).

The last point can be clarified with the following example:

.. code:: jlcon

   julia> using Expect;
   julia> proc = ExpectProc(`echo "a b c "`, 16);
   julia> expect!(proc, " ")
   "a"
   julia> expect!(proc, " ")
   "b"
   julia> expect!(proc, " ")
   "c"

For convenience, ``expect!`` already returns the contents of ``proc.before``
when given a single pattern to match.

``expect!`` however is normally used with a *list* of possible matches to
perform. In this scenario, the index that *matched first* will be returned.
The matched string itself is also available in ``proc.match``. This is useful
to perform conditional processing depending on the command's output:

.. code:: julia

   using Expect
   proc = ExpectProc(`interpreter`, 16)
   println(proc, "perform")
   idx = expect!(proc, ["> ", "ERROR: "])
   if idx == 2
       # error occurred ...
   end

The matches themselves can be regular strings or Regex_ objects. When a Regex
is used, the content of ``proc.match`` contains a match_ object for the element
that matched.

See ``tests/runtests.jl`` for more usage examples.


Reference
---------

Constructor
~~~~~~~~~~~

.. _ExpectProc:

``ExpectProc(cmd, timeout; env, encoding="utf8", pty=true)``:

  Constructs a new ``ExpectProc`` object.

  :cmd: the Cmd_ command to be spawned.
  :timeout: default communication timeout.
  :env: environment for the command (defaults as a copy of the current)
  :encoding: I/O encoding (currently limited to utf8_)
  :pty: request allocation of pty


Functions
~~~~~~~~~

.. _expect!:

``expect!(proc, vector; timeout)``:

  Read the standard output of the program until one of the strings/regular
  expressions specified in ``vector`` matches. The index of the element that
  *matched first* is returned. Matches are searched in sequential order.

  When ``timeout`` is specified, it overrides the default timeout specified in
  the constructor. A value of ``Inf`` waits indefinitely.

  ``proc.before`` is reset at each call to contain all the standard output
  before the match.

  ``proc.match`` contains either a string or a match_ object for the element
  that matched.

``expect!(proc, element; timeout)``:

  Read the standard output of the program until the string/regular
  expressions specified in ``element`` matches. The content of ``proc.before``
  is returned.

.. _with_timeout!:

``with_timeout!(func, proc, timeout)``:

  Modify the default read timeout within the context of ``func``. Normally used
  with the ``do`` syntax:

  .. code:: jl

     proc = ExpectProc(`command`, 1)
     with_timeout!(proc, Inf) do
       # no read timeout within this context
     end


Exceptions
~~~~~~~~~~

.. _ExpectTimeout:

``ExpectTimeout``:

  Reading from the command stalled for the specified number of seconds without
  matching any pattern. Reading *can* continue.

``ExpectEOF``:

  The output ended without matching any of the specified patterns.


Authors and Copyright
---------------------

| "Expect.jl" is distributed under the MIT license (see ``LICENSE.rst``).
| Copyright(c) 2014-2017 by wave++ "Yuri D'Elia" <wavexx@thregr.org>.


.. _Expect: http://www.nist.gov/el/msid/expect.cfm
.. _Cmd: http://julia.readthedocs.org/en/latest/manual/running-external-programs/
.. _readandwrite: http://julia.readthedocs.org/en/latest/stdlib/base/#Base.readandwrite
.. _Regex: http://julia.readthedocs.org/en/latest/manual/strings/#regular-expressions
.. _match: http://julia.readthedocs.org/en/latest/stdlib/strings/#Base.match
.. _utf8: http://julia.readthedocs.org/en/latest/stdlib/strings/#Base.utf8
