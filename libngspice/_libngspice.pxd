# Cython declarations for sharedspice.h.

from libcpp cimport bool

cdef extern from "sharedspice.h":

  cdef struct ngcomplex:
    double cx_real
    double cx_imag

  ctypedef ngcomplex ngcomplex_t

  # vector info obtained from any vector in ngspice.dll.
  # Allows direct access to the ngspice internal vector structure,
  # as defined in include/ngspice/devc.h .
  cdef struct vector_info:
    char *v_name
    int v_type
    short v_flags
    double *v_realdata          # Real data.
    ngcomplex_t *v_compdata     # Complex data.
    int v_length                # Length of the vector.
  ctypedef vector_info* pvector_info

  cdef enum:
    VF_REAL = (1 << 0)          # The data is real.
    VF_COMPLEX = (1 << 1)       # The data is complex.
    VF_ACCUM = (1 << 2)         # writedata should save this vector.
    VF_PLOT = (1 << 3)          # writedata should incrementally plot it.
    VF_PRINT = (1 << 4)         # writedata should print this vector.
    VF_MINGIVEN = (1 << 5)      # The v_minsignal value is valid.
    VF_MAXGIVEN = (1 << 6)      # The v_maxsignal value is valid.
    VF_PERMANENT = (1 << 7)     # Don't garbage collect this vector.

  cdef struct vecvalues:
    char* name          # name of a specific vector
    double creal        # actual data value
    double cimag        # actual data value
    bool is_scale       # if 'name' is the scale vector
    bool is_complex     # if the data are complex numbers
  ctypedef vecvalues* pvecvalues

  ctypedef struct vecvaluesall:
    int veccount        # number of vectors in plot
    int vecindex        # index of actual set of vectors. i.e. the number of accepted data points
    pvecvalues *vecsa   # values of actual set of vectors, indexed from 0 to veccount - 1
  ctypedef vecvaluesall* pvecvaluesall

  # info for a specific vector
  cdef struct vecinfo:
    int number          # number of vector, as postion in the linked list of vectors, starts with 0
    char *vecname       # name of the actual vector
    bool is_real        # TRUE if the actual vector has real data
    void *pdvec         # a void pointer to struct dvec *d, the actual vector
    void *pdvecscale    # a void pointer to struct dvec *ds, the scale vector
  ctypedef vecinfo* pvecinfo

  # info for the current plot
  cdef struct vecinfoall:
    # the plot
    char *name
    char *title
    char *date
    char *type
    int veccount
    # the data as an array of vecinfo with length equal to the number of vectors in the plot
    pvecinfo *vecs;
  ctypedef vecinfoall* pvecinfoall


  # sending output from stdout, stderr to caller
  #   char* string to be sent to caller output
  #   int   identification number of calling ngspice shared lib
  #   void* return pointer received from caller, e.g. pointer to object having sent the request
  ctypedef int SendChar(char*, int, void*)

  # sending simulation status to caller
  #   char* simulation status and value (in percent) to be sent to caller
  #   int   identification number of calling ngspice shared lib
  #   void* return pointer received from caller
  ctypedef int SendStat(char*, int, void*)

  # asking for controlled exit
  #   int   exit status
  #   bool  if true: immediate unloading dll, if false: just set flag, unload is done when function has returned
  #   bool  if true: exit upon 'quit', if false: exit due to ngspice.dll error
  #   int   identification number of calling ngspice shared lib
  #   void* return pointer received from caller
  ctypedef int ControlledExit(int, bool, bool, int, void*)

  # send back actual vector data
  #   vecvaluesall* pointer to array of structs containing actual values from all vectors
  #   int           number of structs (one per vector)
  #   int           identification number of calling ngspice shared lib
  #   void*         return pointer received from caller
  ctypedef int SendData(pvecvaluesall, int, int, void*)

  # send back initialization vector data
  #   vecinfoall* pointer to array of structs containing data from all vectors right after initialization
  #   int         identification number of calling ngspice shared lib
  #   void*       return pointer received from caller
  ctypedef int SendInitData(pvecinfoall, int, void*)

  # indicate if background thread is running
  #   bool        true if background thread is running
  #   int         identification number of calling ngspice shared lib
  #   void*       return pointer received from caller
  ctypedef int BGThreadRunning(bool, int, void*)


  # ngspice initialization,
  #   printfcn: pointer to callback function for reading printf, fprintf
  #   statfcn: pointer to callback function for the status string and percent value
  #   ControlledExit: pointer to callback function for setting a 'quit' signal in caller
  #   SendData: pointer to callback function for returning data values of all current output vectors
  #   SendInitData: pointer to callback function for returning information of all output vectors just initialized
  #   BGThreadRunning: pointer to callback function indicating if workrt thread is running
  #   userData: pointer to user-defined data, will not be modified, but
  #             handed over back to caller during Callback, e.g. address of calling object
  #             userdata will be overridden by new value from here.
  int ngSpice_Init(
      SendChar* printfcn, SendStat* statfcn, ControlledExit* ngexit,
      SendData* sdata, SendInitData* sinitdata, BGThreadRunning* bgtrun,
      void* userData) nogil

  # Caller may send ngspice commands to ngspice.dll.
  # Commands are executed immediately
  int ngSpice_Command(char* command) nogil

  # send a circuit to ngspice.dll
  # The circuit description is a dynamic array
  # of char*. Each char* corresponds to a single circuit
  # line. The last entry of the array has to be a NULL
  int ngSpice_Circ(char** circarray) nogil


  # get info about a vector
  pvector_info ngGet_Vec_Info(char* vecname) nogil

  # return to the caller a pointer to the name of the current plot
  char* ngSpice_CurPlot() nogil

  # return to the caller a pointer to an array of all plots created
  char** ngSpice_AllPlots() nogil

  # return to the caller a pointer to an array of vector names in the plot
  # named by plotname
  char** ngSpice_AllVecs(char* plotname) nogil

  # returns TRUE if ngspice is running in a second (background) thread
  bool ngSpice_running() nogil

  # set a breakpoint in ngspice
  bool ngSpice_SetBkpt(double time) nogil
