#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "perl_math_int64_types.h"
#define MATH_INT64_NATIVE_IF_AVAILABLE
#include "perl_math_int64.h"

#include <archive.h>
#include <archive_entry.h>

#if ARCHIVE_VERSION_NUMBER < 3000000
# if !defined(__LA_INT64_T)
#  if defined(_WIN32) && !defined(__CYGWIN__)
#   define __LA_INT64_T    __int64
#  else
#   if defined(_SCO_DS)
#    define __LA_INT64_T    long long
#   else
#    define __LA_INT64_T    int64_t
#   endif
#  endif
# endif
#endif

#define FORMAT_BSD  1
#define FORMAT_SVR4 2

struct ar_entry;

struct ar {
  struct ar_entry *first;
  int debug;
  int output_format;
  SV *callback;
};

struct ar_entry {
  struct archive_entry *entry;
  const char *data;
  size_t data_size;
  struct ar_entry *next;
};

static void
ar_free_entry(struct ar_entry *entry)
{
  archive_entry_free(entry->entry);
  if(entry->data != NULL)
    Safefree(entry->data);
}

static void
ar_reset(struct ar *ar)
{
  struct ar_entry *entry, *old;
  
  entry = ar->first;
  while(entry != NULL)
  {
    ar_free_entry(entry);
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
ar_write_callback(struct archive *archive, void *cd, const void *buffer, size_t length)
{
  struct ar *ar = (struct ar *)cd;
  int count;
  __LA_INT64_T status;

  dSP;
  ENTER;
  SAVETMPS;
  PUSHMARK(SP);
  XPUSHs(sv_2mortal(newSViv(PTR2IV((void*)archive))));
  XPUSHs(sv_2mortal(newSVpvn(buffer, length)));
  PUTBACK;
  
  call_sv(ar->callback, G_SCALAR);
  
  SPAGAIN;
  
  status = SvI64(POPs);
  
  PUTBACK;
  FREETMPS;
  LEAVE;
  
  return status;
}

static int
ar_close_callback(struct archive *archive, void *client_data)
{
  return ARCHIVE_OK;
}

static __LA_INT64_T
ar_write_archive(struct archive *archive, struct ar *ar)
{
  int r;
  struct ar_entry *entry;
  int count;

  for(entry = ar->first; entry != NULL; entry = entry->next)
  {
    r = archive_write_header(archive, entry->entry);
    if(r < ARCHIVE_OK)
    {
      if(ar->debug)
        warn("%s", archive_error_string(archive));
      if(r != ARCHIVE_WARN)
        return 0;
    }
    r = archive_write_data(archive, entry->data, entry->data_size);
    if(r < ARCHIVE_OK)
    {
      if(ar->debug)
        warn("%s", archive_error_string(archive));
      if(r != ARCHIVE_WARN)
        return 0;
    }
  }

#if ARCHIVE_VERSION_NUMBER < 3000000
  return archive_position_uncompressed(archive);
#else
  return archive_filter_bytes(archive, 0);
#endif
}

static __LA_INT64_T
ar_read_archive(struct archive *archive, struct ar *ar)
{
  struct archive_entry *entry;
  struct ar_entry *e=NULL, *next;
  int r;
  size_t size;
  off_t  offset;

  while(1)
  {
#if HAS_has_archive_read_next_header2
    entry = archive_entry_new();
    r = archive_read_next_header2(archive, entry);
#else
    struct archive_entry *tmp;
    r = archive_read_next_header(archive, &tmp);
    entry = archive_entry_clone(tmp);
#endif
      
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
#if ARCHIVE_VERSION_NUMBER < 3000000
      return archive_position_uncompressed(archive);
#else
      return archive_filter_bytes(archive, 0);
#endif
    }
    else
    {
      warn("%s", archive_error_string(archive));
      ar_reset(ar);
      return 0;
    }

    Newx(next, 1, struct ar_entry);
    next->data_size = archive_entry_size(entry);
    Newx(next->data, next->data_size, char);

    r = archive_read_data(archive, (void*)next->data, next->data_size);

    if(r == ARCHIVE_WARN && ar->debug)
    {
      warn("%s", archive_error_string(archive));
    }
    else if(r < ARCHIVE_OK && r != ARCHIVE_EOF)
    {
      if(ar->debug)
        warn("%s", archive_error_string(archive));
      Safefree(next->data);
      Safefree(next);
      return 0;
    }
    
    next->entry         = entry;
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
    self->first         = NULL;
    self->debug         = 1;
    self->output_format = FORMAT_SVR4;
    self->callback      = NULL;
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
      if(self->debug)
        warn("%s", archive_error_string(archive));
      RETVAL = 0;
    }
#if ARCHIVE_VERSION_NUMBER < 3000000
    archive_read_finish(archive);
#else
    archive_read_free(archive);
#endif
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
    r = archive_read_open(archive, (void*)self, NULL, ar_read_callback, ar_close_callback);

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
#if ARCHIVE_VERSION_NUMBER < 3000000
    archive_read_finish(archive);
#else
    archive_read_free(archive);
#endif
    SvREFCNT_dec(callback);
    self->callback = NULL;
  OUTPUT:
    RETVAL

int
_write_to_filename(self, filename)
    struct ar *self
    const char *filename
  CODE:
    struct archive *archive;
    int r;
    
    archive = archive_write_new();
    if(self->output_format == FORMAT_BSD)
      r = archive_write_set_format_ar_bsd(archive);
    else
      r = archive_write_set_format_ar_svr4(archive);
    if(r != ARCHIVE_OK && self->debug)
      warn("%s", archive_error_string(archive));
    r = archive_write_open_filename(archive, filename);
    if(r != ARCHIVE_OK && self->debug)
      warn("%s", archive_error_string(archive));
    if(r == ARCHIVE_OK || r == ARCHIVE_WARN)
      RETVAL = ar_write_archive(archive, self);
    else
      RETVAL = 0;    
#if ARCHIVE_VERSION_NUMBER < 3000000
    archive_write_finish(archive);
#else
    archive_write_free(archive);
#endif
  OUTPUT:
    RETVAL

int
_write_to_callback(self, callback)
    struct ar *self
    SV *callback
  CODE:
    struct archive *archive;
    int r;
    
    self->callback = SvREFCNT_inc(callback);

    archive = archive_write_new();
    if(self->output_format == FORMAT_BSD)
      r = archive_write_set_format_ar_bsd(archive);
    else
      r = archive_write_set_format_ar_svr4(archive);    
    if(r != ARCHIVE_OK && self->debug)
      warn("%s", archive_error_string(archive));
    r = archive_write_open(archive, (void*)self, NULL, ar_write_callback, ar_close_callback);
    if(r != ARCHIVE_OK && self->debug)
      warn("%s", archive_error_string(archive));
    if(r == ARCHIVE_OK || r == ARCHIVE_WARN)
      RETVAL = ar_write_archive(archive, self);
    else
      RETVAL = 0;
#if ARCHIVE_VERSION_NUMBER < 3000000
    archive_write_finish(archive);
#else
    archive_write_free(archive);    
#endif
    SvREFCNT_dec(callback);
    self->callback = NULL;    
  OUTPUT:
    RETVAL

int
_remove(self,pathname)
    struct ar *self
    const char *pathname
  CODE:
    struct ar_entry **entry;
    entry = &(self->first);
    
    RETVAL = 0;
    
    while(1)
    {
      if(!strcmp(archive_entry_pathname((*entry)->entry),pathname))
      {
        ar_free_entry(*entry);
        *entry = (*entry)->next;
        RETVAL = 1;
        break;
      }
      
      if((*entry)->next == NULL)
        break;
      
      entry = &((*entry)->next);
    }
    
  OUTPUT:
    RETVAL

void
_add_data(self,filename,data,uid,gid,date,mode)
    struct ar *self
    const char *filename
    SV *data
    __LA_INT64_T uid
    __LA_INT64_T gid
    time_t date
    int mode
  CODE:
    struct ar_entry **entry;
    char *buffer;
    
    entry = &(self->first);
    
    while(*entry != NULL)
    {
      entry = &((*entry)->next);
    }
    
    Newx((*entry), 1, struct ar_entry);
    
    (*entry)->entry = archive_entry_new();
    archive_entry_set_pathname((*entry)->entry, filename);
    archive_entry_set_uid((*entry)->entry, uid);
    archive_entry_set_gid((*entry)->entry, gid);
    archive_entry_set_mtime((*entry)->entry, date, date);
    archive_entry_set_mode((*entry)->entry, mode);
    
    (*entry)->next          = NULL;
    
    buffer = SvPV(data, (*entry)->data_size);
    archive_entry_set_size((*entry)->entry, (*entry)->data_size);
    
    Newx((*entry)->data, (*entry)->data_size, char);
    Copy(buffer, (*entry)->data, (*entry)->data_size, char);
    

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

SV *
get_content(self, filename)
    struct ar *self
    const char *filename
  CODE:
    struct ar_entry *entry;
    HV *hv;
    int found;
    
    entry = self->first;
    found = 0;
    
    while(entry != NULL)
    {
      if(!strcmp(archive_entry_pathname(entry->entry), filename))
      {
        hv = newHV();
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"
        hv_store(hv, "name", 4, newSVpv(filename, strlen(filename)),         0);
        hv_store(hv, "date", 4, newSVi64(archive_entry_mtime(entry->entry)), 0);
        hv_store(hv, "uid",  3, newSVi64(archive_entry_uid(entry->entry)),   0);
        hv_store(hv, "gid",  3, newSVi64(archive_entry_gid(entry->entry)),   0);
        hv_store(hv, "mode", 4, newSViv(archive_entry_mode(entry->entry)),   0);
        hv_store(hv, "size", 4, newSViv(entry->data_size),                   0);
        hv_store(hv, "data", 4, newSVpv(entry->data, entry->data_size),      0);
#pragma clang diagnostic pop
        RETVAL = newRV_noinc((SV*)hv);
      
        found = 1;
        break;
      }
      entry = entry->next;
    }
    
    if(!found)
    {
      XSRETURN_EMPTY;
    }
  OUTPUT:
    RETVAL

void
set_output_format_bsd(self)
    struct ar *self
  CODE:
    self->output_format = FORMAT_BSD;

void
set_output_format_svr4(self)
    struct ar *self
  CODE:
    self->output_format = FORMAT_SVR4;
