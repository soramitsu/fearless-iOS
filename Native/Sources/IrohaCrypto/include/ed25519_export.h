
#ifndef ED25519_EXPORT_H
#define ED25519_EXPORT_H

#ifdef ED25519_STATIC_DEFINE
#  define ED25519_EXPORT
#  define ED25519_NO_EXPORT
#else
#  ifndef ED25519_EXPORT
#    ifdef ed25519_EXPORTS
        /* We are building this library */
#      define ED25519_EXPORT 
#    else
        /* We are using this library */
#      define ED25519_EXPORT 
#    endif
#  endif

#  ifndef ED25519_NO_EXPORT
#    define ED25519_NO_EXPORT 
#  endif
#endif

#ifndef ED25519_DEPRECATED
#  define ED25519_DEPRECATED 
#endif

#ifndef ED25519_DEPRECATED_EXPORT
#  define ED25519_DEPRECATED_EXPORT ED25519_EXPORT ED25519_DEPRECATED
#endif

#ifndef ED25519_DEPRECATED_NO_EXPORT
#  define ED25519_DEPRECATED_NO_EXPORT ED25519_NO_EXPORT ED25519_DEPRECATED
#endif

#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef ED25519_NO_DEPRECATED
#    define ED25519_NO_DEPRECATED
#  endif
#endif

#endif /* ED25519_EXPORT_H */
