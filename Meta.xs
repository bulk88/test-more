#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* for typemap */
typedef char PVSV;

#ifdef USE_ITHREADS
int T_S_HB_M_MgDup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
    CV * cv = (CV*)mg->mg_obj;
    SV * key = (SV*)mg->mg_ptr;
    SV * oldkey = (SV*)XSANY.any_ptr; /* for C debugging */
    /* update the void * (really a SV * with a HEK inside) from the new perl interp */
    XSANY.any_ptr = key;
    return 1;
}
const static struct mgvtbl vtbl_T_S_HB_M = {
    NULL, NULL, NULL, NULL, NULL, NULL, T_S_HB_M_MgDup, NULL,
};
#else
/* declare as 5 member, not normal 8 to save image space*/
const static struct {
	int (*svt_get)(SV* sv, MAGIC* mg);
	int (*svt_set)(SV* sv, MAGIC* mg);
	U32 (*svt_len)(SV* sv, MAGIC* mg);
	int (*svt_clear)(SV* sv, MAGIC* mg);
	int (*svt_free)(SV* sv, MAGIC* mg);
} vtbl_T_S_HB_M = {
	NULL, NULL, NULL, NULL, NULL
};
#endif


/* egh, there is a legit get() that isn't an accessor in Test::Stream::HashBase::Meta,
   use non-real (not in PP land) class Test::Stream::HashBase::Meta::XS
*/
XS(XS_Test__Stream__HashBase__Meta__XS_get); /* prototype to pass -Wmissing-prototypes */
XS(XS_Test__Stream__HashBase__Meta__XS_get)
{
    dVAR; dXSARGS;
    if (items != 1)
       croak_xs_usage(cv,  "self");
    {
        HV *    self;
        HE *    he;
        SV *    RETVAL;

        {
            SV* const xsub_tmp_sv = ST(0);
            if (SvROK(xsub_tmp_sv) && SvTYPE(SvRV(xsub_tmp_sv)) == SVt_PVHV){
                self = (HV*)SvRV(xsub_tmp_sv);
            }
            else{
                Perl_croak_nocontext("%s: %s is not a HASH reference",
                            "Test::Stream::HashBase::Meta::XS::get",
                            "self");
            }
        }
        /* lval=1 (create if doesn't exist) or else we would have to throw exceptions or SEGV */
        he = hv_fetch_ent(self, (SV*)XSANY.any_ptr, 1, 0);
        RETVAL = HeVAL(he);
        /* Note we return the live SV* in the hash key, not a copy like PP code does,
           In the very rare case of
           my $ref = \$self->getsomething();
           $$ref = "unauthorized write";
           you can write to inside the obj, but nobody writes perl code like that */
        SvREFCNT_inc_simple_NN(RETVAL);
        RETVAL = sv_2mortal(RETVAL);
        ST(0) = RETVAL;
    }
    XSRETURN(1);
}


XS(XS_Test__Stream__HashBase__Meta__XS_set); /* prototype to pass -Wmissing-prototypes */
XS(XS_Test__Stream__HashBase__Meta__XS_set)
{
    dVAR; dXSARGS;
    SP -= items;
    /* smaller machine code, finish using perl stack ASAP *, frees up registers */
    PUTBACK;
    if (items != 2)
       croak_xs_usage(cv,  "self, val");
    PERL_UNUSED_VAR(ax); /* -Wall */
    {
        HV *    self;
        SV *    val = ST(1);
        HE * he;
        SV * keyval;
        {
            SV* const xsub_tmp_sv = ST(0);
            if (SvROK(xsub_tmp_sv) && SvTYPE(SvRV(xsub_tmp_sv)) == SVt_PVHV){
                self = (HV*)SvRV(xsub_tmp_sv);
            }
            else{
                Perl_croak_nocontext("%s: %s is not a HASH reference",
                            "Test::Stream::HashBase::Meta::XS::set",
                            "self");
            }
        }
        /* dont use newSVsv and hv_store_ent that causes pointless newSV()
        and later a SvREFCNT_dec to swap SV *s in the HE * */
        he = hv_fetch_ent(self, (SV*)XSANY.any_ptr, 1, 0);
        keyval = HeVAL(he);
        sv_setsv(keyval, val);
    }
}

MODULE = Test::Simple		PACKAGE = Test::Stream::HashBase::Meta

PROTOTYPES: DISABLE

# returns a ref to the const sub
CV *
mk_accessor(conststash, constname, constval, getname, setname, keyname )
    HV * conststash
    PVSV * constname
    PVSV * constval
    char * getname
    char * setname
    char * keyname
PREINIT:
#if (PERL_REVISION == 5 && PERL_VERSION < 9)
    char* file = __FILE__;
#else
    const char* file = __FILE__;
#endif
    CV * cv;
    SV * sharedconstval;
#ifdef USE_ITHREADS
    MAGIC * mg;
#endif
CODE:
    /* Create a COW/HEK shared SV *.
      Using this is the fastest possible way to fetch a hash entry.
      On <5.21.2, the hash number of the key will be extracted from this SV *
      instead of being computed from the PV *, and also the PV * of the key SV *
      will be integer pointer compared to the candidate HE's HEK's key char *
      before executing memNE() aka memcmp().
      On >=5.21.2, the HEK * extracted from the shared SV* will be directly
      compared to candidate HE's HEK *. */
    sharedconstval = newSVpvn_share(constval, constvalLen, 0);
    /* takes ownershup of the shared SV* */
    RETVAL = newCONSTSUB_flags(conststash, constname, constnameLen, 0, sharedconstval);
    cv = newXS(getname, XS_Test__Stream__HashBase__Meta__XS_get, file);
    /* easy to read cached copy, so the MG linked list doesn't need to be searched each time, the refcnt is owned by MG struct, not here*/
    XSANY.any_ptr = (void*)sharedconstval;
#ifdef USE_ITHREADS
    /*  with threads, mg_obj has to be "self", AKA the cv, so we can update the
        cv's XS_ANY inside the dup callback later since dup callback just gets
        a MG * and not the containing SV* /CV*. Special logic in sv_magicext
        makes sure a circular reference isn't created with the CV * (not ++ed),
        but sharedconstval will be ++ed by sv_magicext */
    mg = sv_magicext((SV*)cv,(SV*)cv,PERL_MAGIC_ext,&vtbl_T_S_HB_M,(char *)sharedconstval,HEf_SVKEY);
    mg->mg_flags |= MGf_DUP;
#else
    sv_magicext((SV*)cv,NULL,PERL_MAGIC_ext,(const MGVTBL * const)&vtbl_T_S_HB_M,(char *)sharedconstval,HEf_SVKEY);
#endif
    cv = newXS(setname, XS_Test__Stream__HashBase__Meta__XS_set, file);
    /* easy to read cached copy, so the MG linked list doesn't need to be searched each time, the refcnt is owned by MG struct, not here*/
    XSANY.any_ptr = (void*)sharedconstval;
#ifdef USE_ITHREADS
    /*  with threads, mg_obj has to be "self", AKA the cv, so we can update the
        cv's XS_ANY inside the dup callback later since dup callback just gets
        a MG * and not the containing SV* /CV*. Special logic in sv_magicext
        makes sure a circular reference isn't created with the CV * (not ++ed),
        but sharedconstval will be ++ed by sv_magicext */
    mg = sv_magicext((SV*)cv,(SV*)cv,PERL_MAGIC_ext,&vtbl_T_S_HB_M,(char *)sharedconstval,HEf_SVKEY);
    mg->mg_flags |= MGf_DUP;
#else
    sv_magicext((SV*)cv,NULL,PERL_MAGIC_ext,(const MGVTBL * const)&vtbl_T_S_HB_M,(char *)sharedconstval,HEf_SVKEY);
#endif
OUTPUT:
    RETVAL
