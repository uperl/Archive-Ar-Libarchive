#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#ifdef __MINGW32__
#include <stdint.h>
#endif

#define MATH_INT64_NATIVE_IF_AVAILABLE
#include "perl_math_int64.h"

#include <archive.h>
#include <archive_entry.h>

struct ar_entry;

struct ar {
  struct ar_entry *first;
  int debug;
};

struct ar_entry {
  struct archive_entry *entry;
  const char *real_filename;
  const void *data;
  struct ar_entry *next;
};


MODULE = Archive::Ar::Libarchive   PACKAGE = Archive::Ar::Libarchive

BOOT:
     PERL_MATH_INT64_LOAD_OR_CROAK;

struct ar*
_new()
  CODE:
    struct ar *self;
    Newx(self, 1, struct ar);
    self->first = NULL;
    self->debug = 0;
    RETVAL = self;
  OUTPUT:
    RETVAL

int
_get_debug(self)
    struct ar *self
  CODE:
    RETVAL = self->debug;
  OUTPUT:
    RETVAL

void
_set_debug(self, value)
    struct ar *self
    int value
  CODE:
    self->debug = value;
  OUTPUT:
    RETVAL

void
DESTROY(self)
    struct ar *self
  CODE:
    Safefree(self);
