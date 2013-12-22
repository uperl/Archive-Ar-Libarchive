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
  SV *callback;
};

struct ar_entry {
  struct archive_entry *entry;
  const char *real_filename;
  const void *data;
  struct ar_entry *next;
};

static void
ar_reset(struct ar *ar)
{
  struct ar_entry *entry, *old;
  
  entry = ar->first;
  while(entry != NULL)
  {
    archive_entry_free(entry->entry);
    if(entry->real_filename != NULL)
      Safefree(entry->real_filename);
    if(entry->data != NULL)
      Safefree(entry->data);
    old = entry;
    entry = entry->next;
    Safefree(old);
  }
  
  ar->first = NULL;
}

static __LA_SSIZE_T
ar_read_callback(struct archive *archive, void *cd, const void **buffer)
{
  struct ar *ar = (struct ar *)cd;
  int count;
  __LA_INT64_T status;
  STRLEN len;
  SV *sv_buffer;
  
  dSP;
  ENTER;
  SAVETMPS;
  PUSHMARK(SP);
  XPUSHs(sv_2mortal(newSViv(PTR2IV((void*)archive))));
  PUTBACK;
  
  count = call_sv(ar->callback, G_ARRAY);
  
  SPAGAIN;
  
  sv_buffer = SvRV(POPs);
  status = SvI64(POPs);
  if(status == ARCHIVE_OK)
  {
    *buffer = (void*) SvPV(sv_buffer, len);
  }
  
  PUTBACK;
  FREETMPS;
  LEAVE;
  
  if(status == ARCHIVE_OK)
    return len == 1 ? 0 : len;
  else
    return status;  
}
                            

static __LA_INT64_T
ar_read_archive(struct archive *archive, struct ar *ar)
{
  struct archive_entry *entry;
  struct ar_entry *e=NULL, *next;
  int r;

  while(1)
  {
    entry = archive_entry_new();
    r = archive_read_next_header2(archive, entry);
      
    if(r == ARCHIVE_OK)
      ;
    else if(r == ARCHIVE_WARN)
    {
      if(ar->debug)
        warn("%s", archive_error_string(archive));
    }
    else if(r == ARCHIVE_EOF)
    {
      archive_entry_free(entry);
      return archive_filter_bytes(archive, 0);
    }
    else
    {
      warn("%s", archive_error_string(archive));
      ar_reset(ar);
      return 0;
    }
    
    Newx(next, 1, struct ar_entry);
    next->entry         = entry;
    next->real_filename = NULL;
    next->data          = NULL;
    next->next          = NULL;
      
    if(ar->first == NULL)
      ar->first = next;
    else
      e->next = next;      
    e = next;
  }
}

MODULE = Archive::Ar::Libarchive   PACKAGE = Archive::Ar::Libarchive

BOOT:
     PERL_MATH_INT64_LOAD_OR_CROAK;

struct ar*
_new()
  CODE:
    struct ar *self;
    Newx(self, 1, struct ar);
    self->first    = NULL;
    self->debug    = 0;
    self->callback = NULL;
    RETVAL = self;
  OUTPUT:
    RETVAL

int
_read_from_filename(self, filename)
    struct ar *self
    const char *filename
  CODE:
    struct archive *archive;
    int r;

    ar_reset(self);
    archive = archive_read_new();
    archive_read_support_format_ar(archive);

    r = archive_read_open_filename(archive, filename, 1024);
    if(r == ARCHIVE_OK || r == ARCHIVE_WARN)
    {
      if(r == ARCHIVE_WARN && self->debug)
        warn("%s", archive_error_string(archive));
      RETVAL = ar_read_archive(archive, self);
    }
    else
    {
      warn("%s", archive_error_string(archive));
      RETVAL = 0;
    }

    archive_read_free(archive);

  OUTPUT:
    RETVAL

int
_read_from_callback(self, callback)
    struct ar *self
    SV *callback
  CODE:
    struct archive *archive;
    int r;
    
    ar_reset(self);    
    archive = archive_read_new();
    archive_read_support_format_ar(archive);
    
    self->callback = SvREFCNT_inc(callback);
    r = archive_read_open(archive, (void*)self, NULL, ar_read_callback, NULL);

    if(r == ARCHIVE_OK || r == ARCHIVE_WARN)
    {
      if(r == ARCHIVE_WARN && self->debug)
        warn("%s", archive_error_string(archive));
      RETVAL = ar_read_archive(archive, self);
    }
    else
    {
      warn("%s", archive_error_string(archive));
      RETVAL = 0;
    }
    
    SvREFCNT_dec(callback);
    self->callback = NULL;

    archive_read_free(archive);
  OUTPUT:
    RETVAL

SV *
_list_files(self)
    struct ar *self
  CODE:
    AV *list;
    struct ar_entry *entry;
    const char *pathname;
    
    list = newAV();
        
    for(entry = self->first; entry != NULL; entry = entry->next)
    {
      pathname = archive_entry_pathname(entry->entry);
      av_push(list, newSVpv(pathname, strlen(pathname)));
    }
    
    RETVAL = newRV_noinc((SV*)list);
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
    ar_reset(self);
    Safefree(self);
