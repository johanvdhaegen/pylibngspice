# Cython bindings for libngspice.

# cython: c_string_type = str, c_string_encoding=ascii

import enum
import logging

from cpython.complex cimport PyComplex_FromDoubles
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from cpython.ref cimport PyObject
from libcpp cimport bool

import numpy as np
cimport numpy as np

import attr

cimport _libngspice


np.import_array()                       # initialize numpy


LOGGER = logging.getLogger(__name__)


class VTYPE(enum.IntEnum):
  """Vector types."""
  NOTYPE = 0
  TIME = 1
  FREQUENCY = 2
  VOLTAGE = 3
  CURRENT = 4
  VOLTAGE_DENSITY = 5
  CURRENT_DENSITY = 6
  SQR_VOLTAGE_DENSITY = 7
  SQR_CURRENT_DENSITY = 8
  SQR_VOLTAGE = 9
  SQR_CURRENT = 10
  POLE = 11
  ZERO = 12
  SPARAM = 13
  TEMP = 14
  RES = 15
  IMPEDANCE = 16
  ADMITTANCE = 17
  POWER = 18
  PHASE = 19
  DB = 20
  CAPACITANCE = 21
  CHARGE = 22


class VFLAGS(enum.IntFlag):
  """Vector flags."""
  NOFLAGS = 0
  REAL = (1 << 0)
  COMPLEX = (1 << 1)
  ACCUM = (1 << 2)
  PLOT = (1 << 3)
  PRINT = (1 << 4)
  MINGIVEN = (1 << 5)
  MAXGIVEN = (1 << 6)
  PERMANENT = (1 << 7)


@attr.s(kw_only=True, slots=True)
class VectorInfo(object):
  """Vector info data class.

  Attributes:
    name (str): vector name
    vtype (VTYPE): vector type (
    flags (VFLAGS): 
    data (None or float or complex or numpy.ndarray):
      None for data of length 0
      scalar data (float or complex) for data of length 1;
      numpy.ndarray (real or complex) for data of length >1
  """
  name = attr.ib(validator=attr.validators.instance_of(str))
  vtype = attr.ib(
      default=VTYPE.NOTYPE, validator=attr.validators.instance_of(VTYPE))
  flags = attr.ib(
      default=VFLAGS.NOFLAGS, validator=attr.validators.instance_of(VFLAGS))
  data = attr.ib(
      default=0.0, validator=attr.validators.instance_of((
          float, complex, np.ndarray)))


cdef bytes _encode_string(object s, bint allow_none, const char *arg):
  """Convert Python string to bytes."""
  if allow_none and s is None:
    return None
  elif isinstance(s, bytes):            # py2: bytes or str; py3: bytes
    return <bytes>s
  elif isinstance(s, unicode):          # py2: unicode; py3: unicode or str
    return (<unicode>s).encode('ascii')
  else:
    raise TypeError('argument "%s" should be a string' % arg)


cdef _c_str_list(const char* const* list_str):
  """Return list[str] from c const char * const *."""
  cdef list result = []
  cdef size_t idx = 0
  if list_str:
    while list_str[idx] is not NULL:
      result.append(list_str[idx])
      idx += 1
  return result


cdef _c_vec_info(const vector_info *vec):
  """Return Python VectorInfo from c vector_info."""
  if not vec:
    raise ValueError()
  v_type = VTYPE(vec.v_type)
  v_flags = VFLAGS(vec.v_flags)
  cdef np.npy_intp shape = vec.v_length
  cdef object v_data = None
  if v_flags & VFLAGS.REAL and vec.v_realdata is not NULL:
    # convert 0-length real vector to None,
    # 1-length real vector to float,
    # >1-length real vector to 1-D real numpy array
    if vec.v_length == 0:
      v_data = None
    elif vec.v_length == 1:
      v_data = vec.v_realdata[0]
    else:
      # construct a read-only real numpy array using the given data
      v_data = np.PyArray_New(
          np.ndarray, 1, &shape, np.NPY_FLOAT64, NULL,
          vec.v_realdata, 0, np.NPY_ARRAY_CARRAY_RO, <object>NULL)
  elif v_flags & VFLAGS.COMPLEX and vec.v_compdata is not NULL:
    # convert 0-length complex vector to None,
    # 1-length complex vector to complex,
    # >1-length complex vector to 1-D complex numpy array
    if vec.v_length == 0:
      v_data = None
    if vec.v_length == 1:
      v_data = PyComplex_FromDoubles(
          vec.v_compdata[0].cx_real, vec.v_compdata[0].cx_imag)
    else:
      # construct a read-only complex numpy array using the given data
      v_data = np.PyArray_New(
          np.ndarray, 1, &shape, np.NPY_COMPLEX128, NULL,
          vec.v_compdata, 0, np.NPY_ARRAY_CARRAY_RO, <object>NULL)
  # return all info as VectorInfo instance
  return VectorInfo(
      name=vec.v_name, vtype=v_type, flags=v_flags, data=v_data)


cdef int __send_char(char* output, int id, void* data) with gil:
  return (<_NgSpiceSession?> <PyObject*> data).__send_char(output, id)


cdef int __send_stat(char* output, int id, void* data) with gil:
  return (<_NgSpiceSession?> <PyObject*> data).__send_stat(output, id)


cdef int __controlled_exit(
    int status, bool immediate, bool quit, int id, void* data) with gil:
  return (<_NgSpiceSession?> <PyObject*> data).__controlled_exit(
      status, immediate, quit, id)


cdef int __bg_thread_running(bool running, int id, void* data) with gil:
  return (<_NgSpiceSession?> <PyObject*> data).__bg_thread_running(
      running, id)


cdef class _NgSpiceSession:

  cdef bool _bg_thread_running

  cdef _check(_NgSpiceSession self, int result, const char *name):
    if result:
      LOGGER.debug('%s returned %d', name, result)

  cdef int __send_char(_NgSpiceSession self, const char* output, int id):
    stream, msg = output.split(' ', 1)
    LOGGER.info('%s', output)
    return 0

  cdef int __send_stat(_NgSpiceSession self, const char* output, int id):
    LOGGER.info('%s', output)
    return 0

  cdef int __controlled_exit(
      _NgSpiceSession self, int status, bool immediate, bool quit, int id):
    LOGGER.info('Controlled exit (status: %d, immediate: %d, quit: %d)',
                status, immediate, quit)
    return 0

  cdef int __bg_thread_running(_NgSpiceSession self, bool running, int id):
    running = not running               # TODO: bug?
    LOGGER.info('bg thread running: %s', running)
    self._bg_thread_running = running
    return 0

  cdef _init(_NgSpiceSession self, SendChar* printfcn, SendStat* statfcn,
             ControlledExit* ngexit, SendData* sdata, SendInitData* sinitdata,
             BGThreadRunning* bgtrun, void* userData):
    cdef const char *name = 'ngSpice_Init'
    cdef int result = 0
    with nogil:
      result = ngSpice_Init(
          printfcn, statfcn, ngexit, sdata, sinitdata, bgtrun, userData)
    self._check(result, name)

  def __init__(_NgSpiceSession self):
    """Initialize SPICE circuit simulator."""
    self._bg_thread_running = False
    self._init(
        __send_char, __send_stat, __controlled_exit, NULL, NULL,
        __bg_thread_running, <void *> self)

  def cmd(_NgSpiceSession self, command):
    """Execute a NGSPICE command.

    Args:
      command (string): NGSPICE command
    """
    cdef const char *name = 'ngSpice_Cmd'
    command = _encode_string(command, 0, 'command')
    cdef char *command_c = command
    cdef int result = 0
    with nogil:
      result = ngSpice_Command(command_c)
    self._check(result, name)

  def circ(_NgSpiceSession self, circuit):
    """Load a SPICE circuit netlist.

    Arguments:
      circuit (str): SPICE circuit netlist
    """
    cdef const char *name = 'ngSpice_Circ'

    # create a c array of strings from the lines of `circuit`
    circuit_str_list = _encode_string(circuit, 0, 'circuit').split(b'\n')
    cdef char **c_circuit_str_list = <char **>PyMem_Malloc(
        (len(circuit_str_list)+1) * sizeof(char*))
    if not c_circuit_str_list:
      raise MemoryError()
    for idx, val in enumerate(circuit_str_list):
      c_circuit_str_list[idx] = val
    c_circuit_str_list[len(circuit_str_list)] = NULL    # termination

    # call ngSpice_Circ on `circuit`
    cdef int result
    with nogil:
      result = ngSpice_Circ(c_circuit_str_list)

    # clean up: deallocate c array and check result
    PyMem_Free(c_circuit_str_list)
    self._check(result, name)

  def get_plots(_NgSpiceSession self):
    """Returns an array of available plot names (list[str])."""
    return _c_str_list(ngSpice_AllPlots())

  def current_plot(_NgSpiceSession self):
    """Returns the current plot name (str)."""
    return ngSpice_CurPlot()

  def get_vector_names(_NgSpiceSession self, plot):
    """Returns an array of vector names (list[str]) for plot `plot`."""
    return _c_str_list(ngSpice_AllVecs(_encode_string(plot, 0, 'plot')))

  def get_vector_info(_NgSpiceSession self, vec):
    """Returns the vector info for `vec`="<plot>.<vector>"."""
    return _c_vec_info(ngGet_Vec_Info(_encode_string(vec, 0, 'vec')))

  @property
  def is_running(_NgSpiceSession self):
    running = ngSpice_running()
    assert running == self._bg_thread_running
    return running
