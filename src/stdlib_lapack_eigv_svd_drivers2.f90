submodule(stdlib_lapack_eig_svd_lsq) stdlib_lapack_eigv_svd_drivers2
  implicit none


  contains

     module subroutine stdlib_sgesdd( jobz, m, n, a, lda, s, u, ldu, vt, ldvt,work, lwork, iwork, info )
     !! SGESDD computes the singular value decomposition (SVD) of a real
     !! M-by-N matrix A, optionally computing the left and right singular
     !! vectors.  If singular vectors are desired, it uses a
     !! divide-and-conquer algorithm.
     !! The SVD is written
     !! A = U * SIGMA * transpose(V)
     !! where SIGMA is an M-by-N matrix which is zero except for its
     !! min(m,n) diagonal elements, U is an M-by-M orthogonal matrix, and
     !! V is an N-by-N orthogonal matrix.  The diagonal elements of SIGMA
     !! are the singular values of A; they are real and non-negative, and
     !! are returned in descending order.  The first min(m,n) columns of
     !! U and V are the left and right singular vectors of A.
     !! Note that the routine returns VT = V**T, not V.
     !! The divide and conquer algorithm makes very mild assumptions about
     !! floating point arithmetic. It will work on machines with a guard
     !! digit in add/subtract, or on those binary machines without guard
     !! digits which subtract like the Cray X-MP, Cray Y-MP, Cray C-90, or
     !! Cray-2. It could conceivably fail on hexadecimal or decimal machines
     !! without guard digits, but we know of none.
               
        ! -- lapack driver routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_sp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           character, intent(in) :: jobz
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldu, ldvt, lwork, m, n
           ! Array Arguments 
           integer(ilp), intent(out) :: iwork(*)
           real(sp), intent(inout) :: a(lda,*)
           real(sp), intent(out) :: s(*), u(ldu,*), vt(ldvt,*), work(*)
        ! =====================================================================
           
           ! Local Scalars 
           logical(lk) :: lquery, wntqa, wntqas, wntqn, wntqo, wntqs
           integer(ilp) :: bdspac, blk, chunk, i, ie, ierr, il, ir, iscl, itau, itaup, itauq, iu, &
                     ivt, ldwkvt, ldwrkl, ldwrkr, ldwrku, maxwrk, minmn, minwrk, mnthr, nwork, wrkbl
           integer(ilp) :: lwork_sgebrd_mn, lwork_sgebrd_mm, lwork_sgebrd_nn, lwork_sgelqf_mn, &
           lwork_sgeqrf_mn, lwork_sorgbr_p_mm, lwork_sorgbr_q_nn, lwork_sorglq_mn, &
           lwork_sorglq_nn, lwork_sorgqr_mm, lwork_sorgqr_mn, lwork_sormbr_prt_mm, &
           lwork_sormbr_qln_mm, lwork_sormbr_prt_mn, lwork_sormbr_qln_mn, lwork_sormbr_prt_nn, &
                     lwork_sormbr_qln_nn
           real(sp) :: anrm, bignum, eps, smlnum
           ! Local Arrays 
           integer(ilp) :: idum(1_ilp)
           real(sp) :: dum(1_ilp)
           ! Intrinsic Functions 
           ! Executable Statements 
           ! test the input arguments
           info   = 0_ilp
           minmn  = min( m, n )
           wntqa  = stdlib_lsame( jobz, 'A' )
           wntqs  = stdlib_lsame( jobz, 'S' )
           wntqas = wntqa .or. wntqs
           wntqo  = stdlib_lsame( jobz, 'O' )
           wntqn  = stdlib_lsame( jobz, 'N' )
           lquery = ( lwork==-1_ilp )
           if( .not.( wntqa .or. wntqs .or. wntqo .or. wntqn ) ) then
              info = -1_ilp
           else if( m<0_ilp ) then
              info = -2_ilp
           else if( n<0_ilp ) then
              info = -3_ilp
           else if( lda<max( 1_ilp, m ) ) then
              info = -5_ilp
           else if( ldu<1_ilp .or. ( wntqas .and. ldu<m ) .or.( wntqo .and. m<n .and. ldu<m ) ) &
                     then
              info = -8_ilp
           else if( ldvt<1_ilp .or. ( wntqa .and. ldvt<n ) .or.( wntqs .and. ldvt<minmn ) .or.( wntqo &
                     .and. m>=n .and. ldvt<n ) ) then
              info = -10_ilp
           end if
           ! compute workspace
             ! note: comments in the code beginning "workspace:" describe the
             ! minimal amount of workspace allocated at that point in the code,
             ! as well as the preferred amount for good performance.
             ! nb refers to the optimal block size for the immediately
             ! following subroutine, as returned by stdlib_ilaenv.
           if( info==0_ilp ) then
              minwrk = 1_ilp
              maxwrk = 1_ilp
              bdspac = 0_ilp
              mnthr  = int( minmn*11.0_sp / 6.0_sp,KIND=ilp)
              if( m>=n .and. minmn>0_ilp ) then
                 ! compute space needed for stdlib_sbdsdc
                 if( wntqn ) then
                    ! stdlib_sbdsdc needs only 4*n (or 6*n for uplo=l for lapack <= 3.6_sp)
                    ! keep 7*n for backwards compatibility.
                    bdspac = 7_ilp*n
                 else
                    bdspac = 3_ilp*n*n + 4_ilp*n
                 end if
                 ! compute space preferred for each routine
                 call stdlib_sgebrd( m, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), dum(1_ilp),dum(1_ilp), dum(1_ilp), -1_ilp, &
                           ierr )
                 lwork_sgebrd_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sgebrd( n, n, dum(1_ilp), n, dum(1_ilp), dum(1_ilp), dum(1_ilp),dum(1_ilp), dum(1_ilp), -1_ilp, &
                           ierr )
                 lwork_sgebrd_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sgeqrf( m, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_sgeqrf_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sorgbr( 'Q', n, n, n, dum(1_ilp), n, dum(1_ilp), dum(1_ilp), -1_ilp,ierr )
                 lwork_sorgbr_q_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sorgqr( m, m, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_sorgqr_mm = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sorgqr( m, n, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_sorgqr_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sormbr( 'P', 'R', 'T', n, n, n, dum(1_ilp), n,dum(1_ilp), dum(1_ilp), n, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_sormbr_prt_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sormbr( 'Q', 'L', 'N', n, n, n, dum(1_ilp), n,dum(1_ilp), dum(1_ilp), n, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_sormbr_qln_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sormbr( 'Q', 'L', 'N', m, n, n, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_sormbr_qln_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sormbr( 'Q', 'L', 'N', m, m, n, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_sormbr_qln_mm = int( dum(1_ilp),KIND=ilp)
                 if( m>=mnthr ) then
                    if( wntqn ) then
                       ! path 1 (m >> n, jobz='n')
                       wrkbl = n + lwork_sgeqrf_mn
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sgebrd_nn )
                       maxwrk = max( wrkbl, bdspac + n )
                       minwrk = bdspac + n
                    else if( wntqo ) then
                       ! path 2 (m >> n, jobz='o')
                       wrkbl = n + lwork_sgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_sorgqr_mn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sgebrd_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_qln_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_prt_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + bdspac )
                       maxwrk = wrkbl + 2_ilp*n*n
                       minwrk = bdspac + 2_ilp*n*n + 3_ilp*n
                    else if( wntqs ) then
                       ! path 3 (m >> n, jobz='s')
                       wrkbl = n + lwork_sgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_sorgqr_mn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sgebrd_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_qln_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_prt_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + bdspac )
                       maxwrk = wrkbl + n*n
                       minwrk = bdspac + n*n + 3_ilp*n
                    else if( wntqa ) then
                       ! path 4 (m >> n, jobz='a')
                       wrkbl = n + lwork_sgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_sorgqr_mm )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sgebrd_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_qln_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_prt_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + bdspac )
                       maxwrk = wrkbl + n*n
                       minwrk = n*n + max( 3_ilp*n + bdspac, n + m )
                    end if
                 else
                    ! path 5 (m >= n, but not much larger)
                    wrkbl = 3_ilp*n + lwork_sgebrd_mn
                    if( wntqn ) then
                       ! path 5n (m >= n, jobz='n')
                       maxwrk = max( wrkbl, 3_ilp*n + bdspac )
                       minwrk = 3_ilp*n + max( m, bdspac )
                    else if( wntqo ) then
                       ! path 5o (m >= n, jobz='o')
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_prt_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_qln_mn )
                       wrkbl = max( wrkbl, 3_ilp*n + bdspac )
                       maxwrk = wrkbl + m*n
                       minwrk = 3_ilp*n + max( m, n*n + bdspac )
                    else if( wntqs ) then
                       ! path 5s (m >= n, jobz='s')
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_qln_mn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_prt_nn )
                       maxwrk = max( wrkbl, 3_ilp*n + bdspac )
                       minwrk = 3_ilp*n + max( m, bdspac )
                    else if( wntqa ) then
                       ! path 5a (m >= n, jobz='a')
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_sormbr_prt_nn )
                       maxwrk = max( wrkbl, 3_ilp*n + bdspac )
                       minwrk = 3_ilp*n + max( m, bdspac )
                    end if
                 end if
              else if( minmn>0_ilp ) then
                 ! compute space needed for stdlib_sbdsdc
                 if( wntqn ) then
                    ! stdlib_sbdsdc needs only 4*n (or 6*n for uplo=l for lapack <= 3.6_sp)
                    ! keep 7*n for backwards compatibility.
                    bdspac = 7_ilp*m
                 else
                    bdspac = 3_ilp*m*m + 4_ilp*m
                 end if
                 ! compute space preferred for each routine
                 call stdlib_sgebrd( m, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), dum(1_ilp),dum(1_ilp), dum(1_ilp), -1_ilp, &
                           ierr )
                 lwork_sgebrd_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sgebrd( m, m, a, m, s, dum(1_ilp), dum(1_ilp),dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                           
                 lwork_sgebrd_mm = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sgelqf( m, n, a, m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_sgelqf_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sorglq( n, n, m, dum(1_ilp), n, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_sorglq_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sorglq( m, n, m, a, m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_sorglq_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sorgbr( 'P', m, m, m, a, n, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_sorgbr_p_mm = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sormbr( 'P', 'R', 'T', m, m, m, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_sormbr_prt_mm = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sormbr( 'P', 'R', 'T', m, n, m, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_sormbr_prt_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sormbr( 'P', 'R', 'T', n, n, m, dum(1_ilp), n,dum(1_ilp), dum(1_ilp), n, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_sormbr_prt_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_sormbr( 'Q', 'L', 'N', m, m, m, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_sormbr_qln_mm = int( dum(1_ilp),KIND=ilp)
                 if( n>=mnthr ) then
                    if( wntqn ) then
                       ! path 1t (n >> m, jobz='n')
                       wrkbl = m + lwork_sgelqf_mn
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sgebrd_mm )
                       maxwrk = max( wrkbl, bdspac + m )
                       minwrk = bdspac + m
                    else if( wntqo ) then
                       ! path 2t (n >> m, jobz='o')
                       wrkbl = m + lwork_sgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_sorglq_mn )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sgebrd_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_prt_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + bdspac )
                       maxwrk = wrkbl + 2_ilp*m*m
                       minwrk = bdspac + 2_ilp*m*m + 3_ilp*m
                    else if( wntqs ) then
                       ! path 3t (n >> m, jobz='s')
                       wrkbl = m + lwork_sgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_sorglq_mn )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sgebrd_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_prt_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + bdspac )
                       maxwrk = wrkbl + m*m
                       minwrk = bdspac + m*m + 3_ilp*m
                    else if( wntqa ) then
                       ! path 4t (n >> m, jobz='a')
                       wrkbl = m + lwork_sgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_sorglq_nn )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sgebrd_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_prt_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + bdspac )
                       maxwrk = wrkbl + m*m
                       minwrk = m*m + max( 3_ilp*m + bdspac, m + n )
                    end if
                 else
                    ! path 5t (n > m, but not much larger)
                    wrkbl = 3_ilp*m + lwork_sgebrd_mn
                    if( wntqn ) then
                       ! path 5tn (n > m, jobz='n')
                       maxwrk = max( wrkbl, 3_ilp*m + bdspac )
                       minwrk = 3_ilp*m + max( n, bdspac )
                    else if( wntqo ) then
                       ! path 5to (n > m, jobz='o')
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_prt_mn )
                       wrkbl = max( wrkbl, 3_ilp*m + bdspac )
                       maxwrk = wrkbl + m*n
                       minwrk = 3_ilp*m + max( n, m*m + bdspac )
                    else if( wntqs ) then
                       ! path 5ts (n > m, jobz='s')
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_prt_mn )
                       maxwrk = max( wrkbl, 3_ilp*m + bdspac )
                       minwrk = 3_ilp*m + max( n, bdspac )
                    else if( wntqa ) then
                       ! path 5ta (n > m, jobz='a')
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_sormbr_prt_nn )
                       maxwrk = max( wrkbl, 3_ilp*m + bdspac )
                       minwrk = 3_ilp*m + max( n, bdspac )
                    end if
                 end if
              end if
              maxwrk = max( maxwrk, minwrk )
              work( 1_ilp ) = stdlib_sroundup_lwork( maxwrk )
              if( lwork<minwrk .and. .not.lquery ) then
                 info = -12_ilp
              end if
           end if
           if( info/=0_ilp ) then
              call stdlib_xerbla( 'SGESDD', -info )
              return
           else if( lquery ) then
              return
           end if
           ! quick return if possible
           if( m==0_ilp .or. n==0_ilp ) then
              return
           end if
           ! get machine constants
           eps = stdlib_slamch( 'P' )
           smlnum = sqrt( stdlib_slamch( 'S' ) ) / eps
           bignum = one / smlnum
           ! scale a if max element outside range [smlnum,bignum]
           anrm = stdlib_slange( 'M', m, n, a, lda, dum )
           if( stdlib_sisnan( anrm ) ) then
               info = -4_ilp
               return
           end if
           iscl = 0_ilp
           if( anrm>zero .and. anrm<smlnum ) then
              iscl = 1_ilp
              call stdlib_slascl( 'G', 0_ilp, 0_ilp, anrm, smlnum, m, n, a, lda, ierr )
           else if( anrm>bignum ) then
              iscl = 1_ilp
              call stdlib_slascl( 'G', 0_ilp, 0_ilp, anrm, bignum, m, n, a, lda, ierr )
           end if
           if( m>=n ) then
              ! a has at least as many rows as columns. if a has sufficiently
              ! more rows than columns, first reduce using the qr
              ! decomposition (if sufficient workspace available)
              if( m>=mnthr ) then
                 if( wntqn ) then
                    ! path 1 (m >> n, jobz='n')
                    ! no singular vectors to be computed
                    itau = 1_ilp
                    nwork = itau + n
                    ! compute a=q*r
                    ! workspace: need   n [tau] + n    [work]
                    ! workspace: prefer n [tau] + n*nb [work]
                    call stdlib_sgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! zero out below r
                    if (n>1_ilp) call stdlib_slaset( 'L', n-1, n-1, zero, zero, a( 2_ilp, 1_ilp ), lda )
                    ie = 1_ilp
                    itauq = ie + n
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in a
                    ! workspace: need   3*n [e, tauq, taup] + n      [work]
                    ! workspace: prefer 3*n [e, tauq, taup] + 2*n*nb [work]
                    call stdlib_sgebrd( n, n, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                              work( nwork ), lwork-nwork+1,ierr )
                    nwork = ie + n
                    ! perform bidiagonal svd, computing singular values only
                    ! workspace: need   n [e] + bdspac
                    call stdlib_sbdsdc( 'U', 'N', n, s, work( ie ), dum, 1_ilp, dum, 1_ilp,dum, idum, &
                              work( nwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 2 (m >> n, jobz = 'o')
                    ! n left singular vectors to be overwritten on a and
                    ! n right singular vectors to be computed in vt
                    ir = 1_ilp
                    ! work(ir) is ldwrkr by n
                    if( lwork >= lda*n + n*n + 3_ilp*n + bdspac ) then
                       ldwrkr = lda
                    else
                       ldwrkr = ( lwork - n*n - 3_ilp*n - bdspac ) / n
                    end if
                    itau = ir + ldwrkr*n
                    nwork = itau + n
                    ! compute a=q*r
                    ! workspace: need   n*n [r] + n [tau] + n    [work]
                    ! workspace: prefer n*n [r] + n [tau] + n*nb [work]
                    call stdlib_sgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! copy r to work(ir), zeroing out below it
                    call stdlib_slacpy( 'U', n, n, a, lda, work( ir ), ldwrkr )
                    call stdlib_slaset( 'L', n - 1_ilp, n - 1_ilp, zero, zero, work(ir+1),ldwrkr )
                    ! generate q in a
                    ! workspace: need   n*n [r] + n [tau] + n    [work]
                    ! workspace: prefer n*n [r] + n [tau] + n*nb [work]
                    call stdlib_sorgqr( m, n, n, a, lda, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ie = itau
                    itauq = ie + n
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in work(ir)
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n      [work]
                    ! workspace: prefer n*n [r] + 3*n [e, tauq, taup] + 2*n*nb [work]
                    call stdlib_sgebrd( n, n, work( ir ), ldwrkr, s, work( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! work(iu) is n by n
                    iu = nwork
                    nwork = iu + n*n
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in work(iu) and computing right
                    ! singular vectors of bidiagonal matrix in vt
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n*n [u] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', n, s, work( ie ), work( iu ), n,vt, ldvt, dum, &
                              idum, work( nwork ), iwork,info )
                    ! overwrite work(iu) by left singular vectors of r
                    ! and vt by right singular vectors of r
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n*n [u] + n    [work]
                    ! workspace: prefer n*n [r] + 3*n [e, tauq, taup] + n*n [u] + n*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', n, n, n, work( ir ), ldwrkr,work( itauq ), &
                              work( iu ), n, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', n, n, n, work( ir ), ldwrkr,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! multiply q in a by left singular vectors of r in
                    ! work(iu), storing result in work(ir) and copying to a
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n*n [u]
                    ! workspace: prefer m*n [r] + 3*n [e, tauq, taup] + n*n [u]
                    do i = 1, m, ldwrkr
                       chunk = min( m - i + 1_ilp, ldwrkr )
                       call stdlib_sgemm( 'N', 'N', chunk, n, n, one, a( i, 1_ilp ),lda, work( iu ), &
                                 n, zero, work( ir ),ldwrkr )
                       call stdlib_slacpy( 'F', chunk, n, work( ir ), ldwrkr,a( i, 1_ilp ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 3 (m >> n, jobz='s')
                    ! n left singular vectors to be computed in u and
                    ! n right singular vectors to be computed in vt
                    ir = 1_ilp
                    ! work(ir) is n by n
                    ldwrkr = n
                    itau = ir + ldwrkr*n
                    nwork = itau + n
                    ! compute a=q*r
                    ! workspace: need   n*n [r] + n [tau] + n    [work]
                    ! workspace: prefer n*n [r] + n [tau] + n*nb [work]
                    call stdlib_sgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! copy r to work(ir), zeroing out below it
                    call stdlib_slacpy( 'U', n, n, a, lda, work( ir ), ldwrkr )
                    call stdlib_slaset( 'L', n - 1_ilp, n - 1_ilp, zero, zero, work(ir+1),ldwrkr )
                    ! generate q in a
                    ! workspace: need   n*n [r] + n [tau] + n    [work]
                    ! workspace: prefer n*n [r] + n [tau] + n*nb [work]
                    call stdlib_sorgqr( m, n, n, a, lda, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ie = itau
                    itauq = ie + n
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in work(ir)
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n      [work]
                    ! workspace: prefer n*n [r] + 3*n [e, tauq, taup] + 2*n*nb [work]
                    call stdlib_sgebrd( n, n, work( ir ), ldwrkr, s, work( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagoal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', n, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! overwrite u by left singular vectors of r and vt
                    ! by right singular vectors of r
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n    [work]
                    ! workspace: prefer n*n [r] + 3*n [e, tauq, taup] + n*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', n, n, n, work( ir ), ldwrkr,work( itauq ), &
                              u, ldu, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', n, n, n, work( ir ), ldwrkr,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! multiply q in a by left singular vectors of r in
                    ! work(ir), storing result in u
                    ! workspace: need   n*n [r]
                    call stdlib_slacpy( 'F', n, n, u, ldu, work( ir ), ldwrkr )
                    call stdlib_sgemm( 'N', 'N', m, n, n, one, a, lda, work( ir ),ldwrkr, zero, u,&
                               ldu )
                 else if( wntqa ) then
                    ! path 4 (m >> n, jobz='a')
                    ! m left singular vectors to be computed in u and
                    ! n right singular vectors to be computed in vt
                    iu = 1_ilp
                    ! work(iu) is n by n
                    ldwrku = n
                    itau = iu + ldwrku*n
                    nwork = itau + n
                    ! compute a=q*r, copying result to u
                    ! workspace: need   n*n [u] + n [tau] + n    [work]
                    ! workspace: prefer n*n [u] + n [tau] + n*nb [work]
                    call stdlib_sgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    call stdlib_slacpy( 'L', m, n, a, lda, u, ldu )
                    ! generate q in u
                    ! workspace: need   n*n [u] + n [tau] + m    [work]
                    ! workspace: prefer n*n [u] + n [tau] + m*nb [work]
                    call stdlib_sorgqr( m, m, n, u, ldu, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ! produce r in a, zeroing out other entries
                    if (n>1_ilp) call stdlib_slaset( 'L', n-1, n-1, zero, zero, a( 2_ilp, 1_ilp ), lda )
                    ie = itau
                    itauq = ie + n
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in a
                    ! workspace: need   n*n [u] + 3*n [e, tauq, taup] + n      [work]
                    ! workspace: prefer n*n [u] + 3*n [e, tauq, taup] + 2*n*nb [work]
                    call stdlib_sgebrd( n, n, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                              work( nwork ), lwork-nwork+1,ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in work(iu) and computing right
                    ! singular vectors of bidiagonal matrix in vt
                    ! workspace: need   n*n [u] + 3*n [e, tauq, taup] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', n, s, work( ie ), work( iu ), n,vt, ldvt, dum, &
                              idum, work( nwork ), iwork,info )
                    ! overwrite work(iu) by left singular vectors of r and vt
                    ! by right singular vectors of r
                    ! workspace: need   n*n [u] + 3*n [e, tauq, taup] + n    [work]
                    ! workspace: prefer n*n [u] + 3*n [e, tauq, taup] + n*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', n, n, n, a, lda,work( itauq ), work( iu ), &
                              ldwrku,work( nwork ), lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! multiply q in u by left singular vectors of r in
                    ! work(iu), storing result in a
                    ! workspace: need   n*n [u]
                    call stdlib_sgemm( 'N', 'N', m, n, n, one, u, ldu, work( iu ),ldwrku, zero, a,&
                               lda )
                    ! copy left singular vectors of a from a to u
                    call stdlib_slacpy( 'F', m, n, a, lda, u, ldu )
                 end if
              else
                 ! m < mnthr
                 ! path 5 (m >= n, but not much larger)
                 ! reduce to bidiagonal form without qr decomposition
                 ie = 1_ilp
                 itauq = ie + n
                 itaup = itauq + n
                 nwork = itaup + n
                 ! bidiagonalize a
                 ! workspace: need   3*n [e, tauq, taup] + m        [work]
                 ! workspace: prefer 3*n [e, tauq, taup] + (m+n)*nb [work]
                 call stdlib_sgebrd( m, n, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 5n (m >= n, jobz='n')
                    ! perform bidiagonal svd, only computing singular values
                    ! workspace: need   3*n [e, tauq, taup] + bdspac
                    call stdlib_sbdsdc( 'U', 'N', n, s, work( ie ), dum, 1_ilp, dum, 1_ilp,dum, idum, &
                              work( nwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 5o (m >= n, jobz='o')
                    iu = nwork
                    if( lwork >= m*n + 3_ilp*n + bdspac ) then
                       ! work( iu ) is m by n
                       ldwrku = m
                       nwork = iu + ldwrku*n
                       call stdlib_slaset( 'F', m, n, zero, zero, work( iu ),ldwrku )
                       ! ir is unused; silence compile warnings
                       ir = -1_ilp
                    else
                       ! work( iu ) is n by n
                       ldwrku = n
                       nwork = iu + ldwrku*n
                       ! work(ir) is ldwrkr by n
                       ir = nwork
                       ldwrkr = ( lwork - n*n - 3_ilp*n ) / n
                    end if
                    nwork = iu + ldwrku*n
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in work(iu) and computing right
                    ! singular vectors of bidiagonal matrix in vt
                    ! workspace: need   3*n [e, tauq, taup] + n*n [u] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', n, s, work( ie ), work( iu ),ldwrku, vt, ldvt, &
                              dum, idum, work( nwork ),iwork, info )
                    ! overwrite vt by right singular vectors of a
                    ! workspace: need   3*n [e, tauq, taup] + n*n [u] + n    [work]
                    ! workspace: prefer 3*n [e, tauq, taup] + n*n [u] + n*nb [work]
                    call stdlib_sormbr( 'P', 'R', 'T', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    if( lwork >= m*n + 3_ilp*n + bdspac ) then
                       ! path 5o-fast
                       ! overwrite work(iu) by left singular vectors of a
                       ! workspace: need   3*n [e, tauq, taup] + m*n [u] + n    [work]
                       ! workspace: prefer 3*n [e, tauq, taup] + m*n [u] + n*nb [work]
                       call stdlib_sormbr( 'Q', 'L', 'N', m, n, n, a, lda,work( itauq ), work( iu &
                                 ), ldwrku,work( nwork ), lwork - nwork + 1_ilp, ierr )
                       ! copy left singular vectors of a from work(iu) to a
                       call stdlib_slacpy( 'F', m, n, work( iu ), ldwrku, a, lda )
                    else
                       ! path 5o-slow
                       ! generate q in a
                       ! workspace: need   3*n [e, tauq, taup] + n*n [u] + n    [work]
                       ! workspace: prefer 3*n [e, tauq, taup] + n*n [u] + n*nb [work]
                       call stdlib_sorgbr( 'Q', m, n, n, a, lda, work( itauq ),work( nwork ), &
                                 lwork - nwork + 1_ilp, ierr )
                       ! multiply q in a by left singular vectors of
                       ! bidiagonal matrix in work(iu), storing result in
                       ! work(ir) and copying to a
                       ! workspace: need   3*n [e, tauq, taup] + n*n [u] + nb*n [r]
                       ! workspace: prefer 3*n [e, tauq, taup] + n*n [u] + m*n  [r]
                       do i = 1, m, ldwrkr
                          chunk = min( m - i + 1_ilp, ldwrkr )
                          call stdlib_sgemm( 'N', 'N', chunk, n, n, one, a( i, 1_ilp ),lda, work( iu )&
                                    , ldwrku, zero,work( ir ), ldwrkr )
                          call stdlib_slacpy( 'F', chunk, n, work( ir ), ldwrkr,a( i, 1_ilp ), lda )
                                    
                       end do
                    end if
                 else if( wntqs ) then
                    ! path 5s (m >= n, jobz='s')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   3*n [e, tauq, taup] + bdspac
                    call stdlib_slaset( 'F', m, n, zero, zero, u, ldu )
                    call stdlib_sbdsdc( 'U', 'I', n, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! overwrite u by left singular vectors of a and vt
                    ! by right singular vectors of a
                    ! workspace: need   3*n [e, tauq, taup] + n    [work]
                    ! workspace: prefer 3*n [e, tauq, taup] + n*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', m, n, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                 else if( wntqa ) then
                    ! path 5a (m >= n, jobz='a')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   3*n [e, tauq, taup] + bdspac
                    call stdlib_slaset( 'F', m, m, zero, zero, u, ldu )
                    call stdlib_sbdsdc( 'U', 'I', n, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! set the right corner of u to identity matrix
                    if( m>n ) then
                       call stdlib_slaset( 'F', m - n, m - n, zero, one, u(n+1,n+1),ldu )
                    end if
                    ! overwrite u by left singular vectors of a and vt
                    ! by right singular vectors of a
                    ! workspace: need   3*n [e, tauq, taup] + m    [work]
                    ! workspace: prefer 3*n [e, tauq, taup] + m*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', n, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                 end if
              end if
           else
              ! a has more columns than rows. if a has sufficiently more
              ! columns than rows, first reduce using the lq decomposition (if
              ! sufficient workspace available)
              if( n>=mnthr ) then
                 if( wntqn ) then
                    ! path 1t (n >> m, jobz='n')
                    ! no singular vectors to be computed
                    itau = 1_ilp
                    nwork = itau + m
                    ! compute a=l*q
                    ! workspace: need   m [tau] + m [work]
                    ! workspace: prefer m [tau] + m*nb [work]
                    call stdlib_sgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! zero out above l
                    if (m>1_ilp) call stdlib_slaset( 'U', m-1, m-1, zero, zero, a( 1_ilp, 2_ilp ), lda )
                    ie = 1_ilp
                    itauq = ie + m
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in a
                    ! workspace: need   3*m [e, tauq, taup] + m      [work]
                    ! workspace: prefer 3*m [e, tauq, taup] + 2*m*nb [work]
                    call stdlib_sgebrd( m, m, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                              work( nwork ), lwork-nwork+1,ierr )
                    nwork = ie + m
                    ! perform bidiagonal svd, computing singular values only
                    ! workspace: need   m [e] + bdspac
                    call stdlib_sbdsdc( 'U', 'N', m, s, work( ie ), dum, 1_ilp, dum, 1_ilp,dum, idum, &
                              work( nwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 2t (n >> m, jobz='o')
                    ! m right singular vectors to be overwritten on a and
                    ! m left singular vectors to be computed in u
                    ivt = 1_ilp
                    ! work(ivt) is m by m
                    ! work(il)  is m by m; it is later resized to m by chunk for gemm
                    il = ivt + m*m
                    if( lwork >= m*n + m*m + 3_ilp*m + bdspac ) then
                       ldwrkl = m
                       chunk = n
                    else
                       ldwrkl = m
                       chunk = ( lwork - m*m ) / m
                    end if
                    itau = il + ldwrkl*m
                    nwork = itau + m
                    ! compute a=l*q
                    ! workspace: need   m*m [vt] + m*m [l] + m [tau] + m    [work]
                    ! workspace: prefer m*m [vt] + m*m [l] + m [tau] + m*nb [work]
                    call stdlib_sgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! copy l to work(il), zeroing about above it
                    call stdlib_slacpy( 'L', m, m, a, lda, work( il ), ldwrkl )
                    call stdlib_slaset( 'U', m - 1_ilp, m - 1_ilp, zero, zero,work( il + ldwrkl ), ldwrkl &
                              )
                    ! generate q in a
                    ! workspace: need   m*m [vt] + m*m [l] + m [tau] + m    [work]
                    ! workspace: prefer m*m [vt] + m*m [l] + m [tau] + m*nb [work]
                    call stdlib_sorglq( m, n, m, a, lda, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ie = itau
                    itauq = ie + m
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in work(il)
                    ! workspace: need   m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + m      [work]
                    ! workspace: prefer m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + 2*m*nb [work]
                    call stdlib_sgebrd( m, m, work( il ), ldwrkl, s, work( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u, and computing right singular
                    ! vectors of bidiagonal matrix in work(ivt)
                    ! workspace: need   m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', m, s, work( ie ), u, ldu,work( ivt ), m, dum, &
                              idum, work( nwork ),iwork, info )
                    ! overwrite u by left singular vectors of l and work(ivt)
                    ! by right singular vectors of l
                    ! workspace: need   m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + m    [work]
                    ! workspace: prefer m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + m*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', m, m, m, work( il ), ldwrkl,work( itauq ), &
                              u, ldu, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', m, m, m, work( il ), ldwrkl,work( itaup ), &
                              work( ivt ), m,work( nwork ), lwork - nwork + 1_ilp, ierr )
                    ! multiply right singular vectors of l in work(ivt) by q
                    ! in a, storing result in work(il) and copying to a
                    ! workspace: need   m*m [vt] + m*m [l]
                    ! workspace: prefer m*m [vt] + m*n [l]
                    ! at this point, l is resized as m by chunk.
                    do i = 1, n, chunk
                       blk = min( n - i + 1_ilp, chunk )
                       call stdlib_sgemm( 'N', 'N', m, blk, m, one, work( ivt ), m,a( 1_ilp, i ), lda,&
                                  zero, work( il ), ldwrkl )
                       call stdlib_slacpy( 'F', m, blk, work( il ), ldwrkl,a( 1_ilp, i ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 3t (n >> m, jobz='s')
                    ! m right singular vectors to be computed in vt and
                    ! m left singular vectors to be computed in u
                    il = 1_ilp
                    ! work(il) is m by m
                    ldwrkl = m
                    itau = il + ldwrkl*m
                    nwork = itau + m
                    ! compute a=l*q
                    ! workspace: need   m*m [l] + m [tau] + m    [work]
                    ! workspace: prefer m*m [l] + m [tau] + m*nb [work]
                    call stdlib_sgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! copy l to work(il), zeroing out above it
                    call stdlib_slacpy( 'L', m, m, a, lda, work( il ), ldwrkl )
                    call stdlib_slaset( 'U', m - 1_ilp, m - 1_ilp, zero, zero,work( il + ldwrkl ), ldwrkl &
                              )
                    ! generate q in a
                    ! workspace: need   m*m [l] + m [tau] + m    [work]
                    ! workspace: prefer m*m [l] + m [tau] + m*nb [work]
                    call stdlib_sorglq( m, n, m, a, lda, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ie = itau
                    itauq = ie + m
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in work(iu).
                    ! workspace: need   m*m [l] + 3*m [e, tauq, taup] + m      [work]
                    ! workspace: prefer m*m [l] + 3*m [e, tauq, taup] + 2*m*nb [work]
                    call stdlib_sgebrd( m, m, work( il ), ldwrkl, s, work( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   m*m [l] + 3*m [e, tauq, taup] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', m, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! overwrite u by left singular vectors of l and vt
                    ! by right singular vectors of l
                    ! workspace: need   m*m [l] + 3*m [e, tauq, taup] + m    [work]
                    ! workspace: prefer m*m [l] + 3*m [e, tauq, taup] + m*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', m, m, m, work( il ), ldwrkl,work( itauq ), &
                              u, ldu, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', m, m, m, work( il ), ldwrkl,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! multiply right singular vectors of l in work(il) by
                    ! q in a, storing result in vt
                    ! workspace: need   m*m [l]
                    call stdlib_slacpy( 'F', m, m, vt, ldvt, work( il ), ldwrkl )
                    call stdlib_sgemm( 'N', 'N', m, n, m, one, work( il ), ldwrkl,a, lda, zero, &
                              vt, ldvt )
                 else if( wntqa ) then
                    ! path 4t (n >> m, jobz='a')
                    ! n right singular vectors to be computed in vt and
                    ! m left singular vectors to be computed in u
                    ivt = 1_ilp
                    ! work(ivt) is m by m
                    ldwkvt = m
                    itau = ivt + ldwkvt*m
                    nwork = itau + m
                    ! compute a=l*q, copying result to vt
                    ! workspace: need   m*m [vt] + m [tau] + m    [work]
                    ! workspace: prefer m*m [vt] + m [tau] + m*nb [work]
                    call stdlib_sgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    call stdlib_slacpy( 'U', m, n, a, lda, vt, ldvt )
                    ! generate q in vt
                    ! workspace: need   m*m [vt] + m [tau] + n    [work]
                    ! workspace: prefer m*m [vt] + m [tau] + n*nb [work]
                    call stdlib_sorglq( n, n, m, vt, ldvt, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ! produce l in a, zeroing out other entries
                    if (m>1_ilp) call stdlib_slaset( 'U', m-1, m-1, zero, zero, a( 1_ilp, 2_ilp ), lda )
                    ie = itau
                    itauq = ie + m
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in a
                    ! workspace: need   m*m [vt] + 3*m [e, tauq, taup] + m      [work]
                    ! workspace: prefer m*m [vt] + 3*m [e, tauq, taup] + 2*m*nb [work]
                    call stdlib_sgebrd( m, m, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                              work( nwork ), lwork-nwork+1,ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in work(ivt)
                    ! workspace: need   m*m [vt] + 3*m [e, tauq, taup] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', m, s, work( ie ), u, ldu,work( ivt ), ldwkvt, &
                              dum, idum,work( nwork ), iwork, info )
                    ! overwrite u by left singular vectors of l and work(ivt)
                    ! by right singular vectors of l
                    ! workspace: need   m*m [vt] + 3*m [e, tauq, taup]+ m    [work]
                    ! workspace: prefer m*m [vt] + 3*m [e, tauq, taup]+ m*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', m, m, m, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', m, m, m, a, lda,work( itaup ), work( ivt ),&
                               ldwkvt,work( nwork ), lwork - nwork + 1_ilp, ierr )
                    ! multiply right singular vectors of l in work(ivt) by
                    ! q in vt, storing result in a
                    ! workspace: need   m*m [vt]
                    call stdlib_sgemm( 'N', 'N', m, n, m, one, work( ivt ), ldwkvt,vt, ldvt, zero,&
                               a, lda )
                    ! copy right singular vectors of a from a to vt
                    call stdlib_slacpy( 'F', m, n, a, lda, vt, ldvt )
                 end if
              else
                 ! n < mnthr
                 ! path 5t (n > m, but not much larger)
                 ! reduce to bidiagonal form without lq decomposition
                 ie = 1_ilp
                 itauq = ie + m
                 itaup = itauq + m
                 nwork = itaup + m
                 ! bidiagonalize a
                 ! workspace: need   3*m [e, tauq, taup] + n        [work]
                 ! workspace: prefer 3*m [e, tauq, taup] + (m+n)*nb [work]
                 call stdlib_sgebrd( m, n, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 5tn (n > m, jobz='n')
                    ! perform bidiagonal svd, only computing singular values
                    ! workspace: need   3*m [e, tauq, taup] + bdspac
                    call stdlib_sbdsdc( 'L', 'N', m, s, work( ie ), dum, 1_ilp, dum, 1_ilp,dum, idum, &
                              work( nwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 5to (n > m, jobz='o')
                    ldwkvt = m
                    ivt = nwork
                    if( lwork >= m*n + 3_ilp*m + bdspac ) then
                       ! work( ivt ) is m by n
                       call stdlib_slaset( 'F', m, n, zero, zero, work( ivt ),ldwkvt )
                       nwork = ivt + ldwkvt*n
                       ! il is unused; silence compile warnings
                       il = -1_ilp
                    else
                       ! work( ivt ) is m by m
                       nwork = ivt + ldwkvt*m
                       il = nwork
                       ! work(il) is m by chunk
                       chunk = ( lwork - m*m - 3_ilp*m ) / m
                    end if
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in work(ivt)
                    ! workspace: need   3*m [e, tauq, taup] + m*m [vt] + bdspac
                    call stdlib_sbdsdc( 'L', 'I', m, s, work( ie ), u, ldu,work( ivt ), ldwkvt, &
                              dum, idum,work( nwork ), iwork, info )
                    ! overwrite u by left singular vectors of a
                    ! workspace: need   3*m [e, tauq, taup] + m*m [vt] + m    [work]
                    ! workspace: prefer 3*m [e, tauq, taup] + m*m [vt] + m*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    if( lwork >= m*n + 3_ilp*m + bdspac ) then
                       ! path 5to-fast
                       ! overwrite work(ivt) by left singular vectors of a
                       ! workspace: need   3*m [e, tauq, taup] + m*n [vt] + m    [work]
                       ! workspace: prefer 3*m [e, tauq, taup] + m*n [vt] + m*nb [work]
                       call stdlib_sormbr( 'P', 'R', 'T', m, n, m, a, lda,work( itaup ), work( &
                                 ivt ), ldwkvt,work( nwork ), lwork - nwork + 1_ilp, ierr )
                       ! copy right singular vectors of a from work(ivt) to a
                       call stdlib_slacpy( 'F', m, n, work( ivt ), ldwkvt, a, lda )
                    else
                       ! path 5to-slow
                       ! generate p**t in a
                       ! workspace: need   3*m [e, tauq, taup] + m*m [vt] + m    [work]
                       ! workspace: prefer 3*m [e, tauq, taup] + m*m [vt] + m*nb [work]
                       call stdlib_sorgbr( 'P', m, n, m, a, lda, work( itaup ),work( nwork ), &
                                 lwork - nwork + 1_ilp, ierr )
                       ! multiply q in a by right singular vectors of
                       ! bidiagonal matrix in work(ivt), storing result in
                       ! work(il) and copying to a
                       ! workspace: need   3*m [e, tauq, taup] + m*m [vt] + m*nb [l]
                       ! workspace: prefer 3*m [e, tauq, taup] + m*m [vt] + m*n  [l]
                       do i = 1, n, chunk
                          blk = min( n - i + 1_ilp, chunk )
                          call stdlib_sgemm( 'N', 'N', m, blk, m, one, work( ivt ),ldwkvt, a( 1_ilp, &
                                    i ), lda, zero,work( il ), m )
                          call stdlib_slacpy( 'F', m, blk, work( il ), m, a( 1_ilp, i ),lda )
                       end do
                    end if
                 else if( wntqs ) then
                    ! path 5ts (n > m, jobz='s')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   3*m [e, tauq, taup] + bdspac
                    call stdlib_slaset( 'F', m, n, zero, zero, vt, ldvt )
                    call stdlib_sbdsdc( 'L', 'I', m, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! overwrite u by left singular vectors of a and vt
                    ! by right singular vectors of a
                    ! workspace: need   3*m [e, tauq, taup] + m    [work]
                    ! workspace: prefer 3*m [e, tauq, taup] + m*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', m, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                 else if( wntqa ) then
                    ! path 5ta (n > m, jobz='a')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   3*m [e, tauq, taup] + bdspac
                    call stdlib_slaset( 'F', n, n, zero, zero, vt, ldvt )
                    call stdlib_sbdsdc( 'L', 'I', m, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! set the right corner of vt to identity matrix
                    if( n>m ) then
                       call stdlib_slaset( 'F', n-m, n-m, zero, one, vt(m+1,m+1),ldvt )
                    end if
                    ! overwrite u by left singular vectors of a and vt
                    ! by right singular vectors of a
                    ! workspace: need   3*m [e, tauq, taup] + n    [work]
                    ! workspace: prefer 3*m [e, tauq, taup] + n*nb [work]
                    call stdlib_sormbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_sormbr( 'P', 'R', 'T', n, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                 end if
              end if
           end if
           ! undo scaling if necessary
           if( iscl==1_ilp ) then
              if( anrm>bignum )call stdlib_slascl( 'G', 0_ilp, 0_ilp, bignum, anrm, minmn, 1_ilp, s, minmn,&
                        ierr )
              if( anrm<smlnum )call stdlib_slascl( 'G', 0_ilp, 0_ilp, smlnum, anrm, minmn, 1_ilp, s, minmn,&
                        ierr )
           end if
           ! return optimal workspace in work(1)
           work( 1_ilp ) = stdlib_sroundup_lwork( maxwrk )
           return
     end subroutine stdlib_sgesdd

     module subroutine stdlib_dgesdd( jobz, m, n, a, lda, s, u, ldu, vt, ldvt,work, lwork, iwork, info )
     !! DGESDD computes the singular value decomposition (SVD) of a real
     !! M-by-N matrix A, optionally computing the left and right singular
     !! vectors.  If singular vectors are desired, it uses a
     !! divide-and-conquer algorithm.
     !! The SVD is written
     !! A = U * SIGMA * transpose(V)
     !! where SIGMA is an M-by-N matrix which is zero except for its
     !! min(m,n) diagonal elements, U is an M-by-M orthogonal matrix, and
     !! V is an N-by-N orthogonal matrix.  The diagonal elements of SIGMA
     !! are the singular values of A; they are real and non-negative, and
     !! are returned in descending order.  The first min(m,n) columns of
     !! U and V are the left and right singular vectors of A.
     !! Note that the routine returns VT = V**T, not V.
     !! The divide and conquer algorithm makes very mild assumptions about
     !! floating point arithmetic. It will work on machines with a guard
     !! digit in add/subtract, or on those binary machines without guard
     !! digits which subtract like the Cray X-MP, Cray Y-MP, Cray C-90, or
     !! Cray-2. It could conceivably fail on hexadecimal or decimal machines
     !! without guard digits, but we know of none.
               
        ! -- lapack driver routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_dp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           character, intent(in) :: jobz
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldu, ldvt, lwork, m, n
           ! Array Arguments 
           integer(ilp), intent(out) :: iwork(*)
           real(dp), intent(inout) :: a(lda,*)
           real(dp), intent(out) :: s(*), u(ldu,*), vt(ldvt,*), work(*)
        ! =====================================================================
           
           ! Local Scalars 
           logical(lk) :: lquery, wntqa, wntqas, wntqn, wntqo, wntqs
           integer(ilp) :: bdspac, blk, chunk, i, ie, ierr, il, ir, iscl, itau, itaup, itauq, iu, &
                     ivt, ldwkvt, ldwrkl, ldwrkr, ldwrku, maxwrk, minmn, minwrk, mnthr, nwork, wrkbl
           integer(ilp) :: lwork_dgebrd_mn, lwork_dgebrd_mm, lwork_dgebrd_nn, lwork_dgelqf_mn, &
           lwork_dgeqrf_mn, lwork_dorgbr_p_mm, lwork_dorgbr_q_nn, lwork_dorglq_mn, &
           lwork_dorglq_nn, lwork_dorgqr_mm, lwork_dorgqr_mn, lwork_dormbr_prt_mm, &
           lwork_dormbr_qln_mm, lwork_dormbr_prt_mn, lwork_dormbr_qln_mn, lwork_dormbr_prt_nn, &
                     lwork_dormbr_qln_nn
           real(dp) :: anrm, bignum, eps, smlnum
           ! Local Arrays 
           integer(ilp) :: idum(1_ilp)
           real(dp) :: dum(1_ilp)
           ! Intrinsic Functions 
           ! Executable Statements 
           ! test the input arguments
           info   = 0_ilp
           minmn  = min( m, n )
           wntqa  = stdlib_lsame( jobz, 'A' )
           wntqs  = stdlib_lsame( jobz, 'S' )
           wntqas = wntqa .or. wntqs
           wntqo  = stdlib_lsame( jobz, 'O' )
           wntqn  = stdlib_lsame( jobz, 'N' )
           lquery = ( lwork==-1_ilp )
           if( .not.( wntqa .or. wntqs .or. wntqo .or. wntqn ) ) then
              info = -1_ilp
           else if( m<0_ilp ) then
              info = -2_ilp
           else if( n<0_ilp ) then
              info = -3_ilp
           else if( lda<max( 1_ilp, m ) ) then
              info = -5_ilp
           else if( ldu<1_ilp .or. ( wntqas .and. ldu<m ) .or.( wntqo .and. m<n .and. ldu<m ) ) &
                     then
              info = -8_ilp
           else if( ldvt<1_ilp .or. ( wntqa .and. ldvt<n ) .or.( wntqs .and. ldvt<minmn ) .or.( wntqo &
                     .and. m>=n .and. ldvt<n ) ) then
              info = -10_ilp
           end if
           ! compute workspace
             ! note: comments in the code beginning "workspace:" describe the
             ! minimal amount of workspace allocated at that point in the code,
             ! as well as the preferred amount for good performance.
             ! nb refers to the optimal block size for the immediately
             ! following subroutine, as returned by stdlib_ilaenv.
           if( info==0_ilp ) then
              minwrk = 1_ilp
              maxwrk = 1_ilp
              bdspac = 0_ilp
              mnthr  = int( minmn*11.0_dp / 6.0_dp,KIND=ilp)
              if( m>=n .and. minmn>0_ilp ) then
                 ! compute space needed for stdlib_dbdsdc
                 if( wntqn ) then
                    ! stdlib_dbdsdc needs only 4*n (or 6*n for uplo=l for lapack <= 3.6_dp)
                    ! keep 7*n for backwards compatibility.
                    bdspac = 7_ilp*n
                 else
                    bdspac = 3_ilp*n*n + 4_ilp*n
                 end if
                 ! compute space preferred for each routine
                 call stdlib_dgebrd( m, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), dum(1_ilp),dum(1_ilp), dum(1_ilp), -1_ilp, &
                           ierr )
                 lwork_dgebrd_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dgebrd( n, n, dum(1_ilp), n, dum(1_ilp), dum(1_ilp), dum(1_ilp),dum(1_ilp), dum(1_ilp), -1_ilp, &
                           ierr )
                 lwork_dgebrd_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dgeqrf( m, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_dgeqrf_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dorgbr( 'Q', n, n, n, dum(1_ilp), n, dum(1_ilp), dum(1_ilp), -1_ilp,ierr )
                 lwork_dorgbr_q_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dorgqr( m, m, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_dorgqr_mm = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dorgqr( m, n, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_dorgqr_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dormbr( 'P', 'R', 'T', n, n, n, dum(1_ilp), n,dum(1_ilp), dum(1_ilp), n, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_dormbr_prt_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dormbr( 'Q', 'L', 'N', n, n, n, dum(1_ilp), n,dum(1_ilp), dum(1_ilp), n, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_dormbr_qln_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dormbr( 'Q', 'L', 'N', m, n, n, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_dormbr_qln_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dormbr( 'Q', 'L', 'N', m, m, n, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_dormbr_qln_mm = int( dum(1_ilp),KIND=ilp)
                 if( m>=mnthr ) then
                    if( wntqn ) then
                       ! path 1 (m >> n, jobz='n')
                       wrkbl = n + lwork_dgeqrf_mn
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dgebrd_nn )
                       maxwrk = max( wrkbl, bdspac + n )
                       minwrk = bdspac + n
                    else if( wntqo ) then
                       ! path 2 (m >> n, jobz='o')
                       wrkbl = n + lwork_dgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_dorgqr_mn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dgebrd_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_qln_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_prt_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + bdspac )
                       maxwrk = wrkbl + 2_ilp*n*n
                       minwrk = bdspac + 2_ilp*n*n + 3_ilp*n
                    else if( wntqs ) then
                       ! path 3 (m >> n, jobz='s')
                       wrkbl = n + lwork_dgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_dorgqr_mn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dgebrd_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_qln_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_prt_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + bdspac )
                       maxwrk = wrkbl + n*n
                       minwrk = bdspac + n*n + 3_ilp*n
                    else if( wntqa ) then
                       ! path 4 (m >> n, jobz='a')
                       wrkbl = n + lwork_dgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_dorgqr_mm )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dgebrd_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_qln_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_prt_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + bdspac )
                       maxwrk = wrkbl + n*n
                       minwrk = n*n + max( 3_ilp*n + bdspac, n + m )
                    end if
                 else
                    ! path 5 (m >= n, but not much larger)
                    wrkbl = 3_ilp*n + lwork_dgebrd_mn
                    if( wntqn ) then
                       ! path 5n (m >= n, jobz='n')
                       maxwrk = max( wrkbl, 3_ilp*n + bdspac )
                       minwrk = 3_ilp*n + max( m, bdspac )
                    else if( wntqo ) then
                       ! path 5o (m >= n, jobz='o')
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_prt_nn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_qln_mn )
                       wrkbl = max( wrkbl, 3_ilp*n + bdspac )
                       maxwrk = wrkbl + m*n
                       minwrk = 3_ilp*n + max( m, n*n + bdspac )
                    else if( wntqs ) then
                       ! path 5s (m >= n, jobz='s')
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_qln_mn )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_prt_nn )
                       maxwrk = max( wrkbl, 3_ilp*n + bdspac )
                       minwrk = 3_ilp*n + max( m, bdspac )
                    else if( wntqa ) then
                       ! path 5a (m >= n, jobz='a')
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*n + lwork_dormbr_prt_nn )
                       maxwrk = max( wrkbl, 3_ilp*n + bdspac )
                       minwrk = 3_ilp*n + max( m, bdspac )
                    end if
                 end if
              else if( minmn>0_ilp ) then
                 ! compute space needed for stdlib_dbdsdc
                 if( wntqn ) then
                    ! stdlib_dbdsdc needs only 4*n (or 6*n for uplo=l for lapack <= 3.6_dp)
                    ! keep 7*n for backwards compatibility.
                    bdspac = 7_ilp*m
                 else
                    bdspac = 3_ilp*m*m + 4_ilp*m
                 end if
                 ! compute space preferred for each routine
                 call stdlib_dgebrd( m, n, dum(1_ilp), m, dum(1_ilp), dum(1_ilp), dum(1_ilp),dum(1_ilp), dum(1_ilp), -1_ilp, &
                           ierr )
                 lwork_dgebrd_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dgebrd( m, m, a, m, s, dum(1_ilp), dum(1_ilp),dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                           
                 lwork_dgebrd_mm = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dgelqf( m, n, a, m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_dgelqf_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dorglq( n, n, m, dum(1_ilp), n, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_dorglq_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dorglq( m, n, m, a, m, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_dorglq_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dorgbr( 'P', m, m, m, a, n, dum(1_ilp), dum(1_ilp), -1_ilp, ierr )
                 lwork_dorgbr_p_mm = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dormbr( 'P', 'R', 'T', m, m, m, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_dormbr_prt_mm = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dormbr( 'P', 'R', 'T', m, n, m, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_dormbr_prt_mn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dormbr( 'P', 'R', 'T', n, n, m, dum(1_ilp), n,dum(1_ilp), dum(1_ilp), n, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_dormbr_prt_nn = int( dum(1_ilp),KIND=ilp)
                 call stdlib_dormbr( 'Q', 'L', 'N', m, m, m, dum(1_ilp), m,dum(1_ilp), dum(1_ilp), m, dum(1_ilp), &
                           -1_ilp, ierr )
                 lwork_dormbr_qln_mm = int( dum(1_ilp),KIND=ilp)
                 if( n>=mnthr ) then
                    if( wntqn ) then
                       ! path 1t (n >> m, jobz='n')
                       wrkbl = m + lwork_dgelqf_mn
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dgebrd_mm )
                       maxwrk = max( wrkbl, bdspac + m )
                       minwrk = bdspac + m
                    else if( wntqo ) then
                       ! path 2t (n >> m, jobz='o')
                       wrkbl = m + lwork_dgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_dorglq_mn )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dgebrd_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_prt_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + bdspac )
                       maxwrk = wrkbl + 2_ilp*m*m
                       minwrk = bdspac + 2_ilp*m*m + 3_ilp*m
                    else if( wntqs ) then
                       ! path 3t (n >> m, jobz='s')
                       wrkbl = m + lwork_dgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_dorglq_mn )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dgebrd_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_prt_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + bdspac )
                       maxwrk = wrkbl + m*m
                       minwrk = bdspac + m*m + 3_ilp*m
                    else if( wntqa ) then
                       ! path 4t (n >> m, jobz='a')
                       wrkbl = m + lwork_dgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_dorglq_nn )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dgebrd_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_prt_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + bdspac )
                       maxwrk = wrkbl + m*m
                       minwrk = m*m + max( 3_ilp*m + bdspac, m + n )
                    end if
                 else
                    ! path 5t (n > m, but not much larger)
                    wrkbl = 3_ilp*m + lwork_dgebrd_mn
                    if( wntqn ) then
                       ! path 5tn (n > m, jobz='n')
                       maxwrk = max( wrkbl, 3_ilp*m + bdspac )
                       minwrk = 3_ilp*m + max( n, bdspac )
                    else if( wntqo ) then
                       ! path 5to (n > m, jobz='o')
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_prt_mn )
                       wrkbl = max( wrkbl, 3_ilp*m + bdspac )
                       maxwrk = wrkbl + m*n
                       minwrk = 3_ilp*m + max( n, m*m + bdspac )
                    else if( wntqs ) then
                       ! path 5ts (n > m, jobz='s')
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_prt_mn )
                       maxwrk = max( wrkbl, 3_ilp*m + bdspac )
                       minwrk = 3_ilp*m + max( n, bdspac )
                    else if( wntqa ) then
                       ! path 5ta (n > m, jobz='a')
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_qln_mm )
                       wrkbl = max( wrkbl, 3_ilp*m + lwork_dormbr_prt_nn )
                       maxwrk = max( wrkbl, 3_ilp*m + bdspac )
                       minwrk = 3_ilp*m + max( n, bdspac )
                    end if
                 end if
              end if
              maxwrk = max( maxwrk, minwrk )
              work( 1_ilp ) = stdlib_droundup_lwork( maxwrk )
              if( lwork<minwrk .and. .not.lquery ) then
                 info = -12_ilp
              end if
           end if
           if( info/=0_ilp ) then
              call stdlib_xerbla( 'DGESDD', -info )
              return
           else if( lquery ) then
              return
           end if
           ! quick return if possible
           if( m==0_ilp .or. n==0_ilp ) then
              return
           end if
           ! get machine constants
           eps = stdlib_dlamch( 'P' )
           smlnum = sqrt( stdlib_dlamch( 'S' ) ) / eps
           bignum = one / smlnum
           ! scale a if max element outside range [smlnum,bignum]
           anrm = stdlib_dlange( 'M', m, n, a, lda, dum )
           if( stdlib_disnan( anrm ) ) then
               info = -4_ilp
               return
           end if
           iscl = 0_ilp
           if( anrm>zero .and. anrm<smlnum ) then
              iscl = 1_ilp
              call stdlib_dlascl( 'G', 0_ilp, 0_ilp, anrm, smlnum, m, n, a, lda, ierr )
           else if( anrm>bignum ) then
              iscl = 1_ilp
              call stdlib_dlascl( 'G', 0_ilp, 0_ilp, anrm, bignum, m, n, a, lda, ierr )
           end if
           if( m>=n ) then
              ! a has at least as many rows as columns. if a has sufficiently
              ! more rows than columns, first reduce using the qr
              ! decomposition (if sufficient workspace available)
              if( m>=mnthr ) then
                 if( wntqn ) then
                    ! path 1 (m >> n, jobz='n')
                    ! no singular vectors to be computed
                    itau = 1_ilp
                    nwork = itau + n
                    ! compute a=q*r
                    ! workspace: need   n [tau] + n    [work]
                    ! workspace: prefer n [tau] + n*nb [work]
                    call stdlib_dgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! zero out below r
                    if (n>1_ilp) call stdlib_dlaset( 'L', n-1, n-1, zero, zero, a( 2_ilp, 1_ilp ), lda )
                    ie = 1_ilp
                    itauq = ie + n
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in a
                    ! workspace: need   3*n [e, tauq, taup] + n      [work]
                    ! workspace: prefer 3*n [e, tauq, taup] + 2*n*nb [work]
                    call stdlib_dgebrd( n, n, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                              work( nwork ), lwork-nwork+1,ierr )
                    nwork = ie + n
                    ! perform bidiagonal svd, computing singular values only
                    ! workspace: need   n [e] + bdspac
                    call stdlib_dbdsdc( 'U', 'N', n, s, work( ie ), dum, 1_ilp, dum, 1_ilp,dum, idum, &
                              work( nwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 2 (m >> n, jobz = 'o')
                    ! n left singular vectors to be overwritten on a and
                    ! n right singular vectors to be computed in vt
                    ir = 1_ilp
                    ! work(ir) is ldwrkr by n
                    if( lwork >= lda*n + n*n + 3_ilp*n + bdspac ) then
                       ldwrkr = lda
                    else
                       ldwrkr = ( lwork - n*n - 3_ilp*n - bdspac ) / n
                    end if
                    itau = ir + ldwrkr*n
                    nwork = itau + n
                    ! compute a=q*r
                    ! workspace: need   n*n [r] + n [tau] + n    [work]
                    ! workspace: prefer n*n [r] + n [tau] + n*nb [work]
                    call stdlib_dgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! copy r to work(ir), zeroing out below it
                    call stdlib_dlacpy( 'U', n, n, a, lda, work( ir ), ldwrkr )
                    call stdlib_dlaset( 'L', n - 1_ilp, n - 1_ilp, zero, zero, work(ir+1),ldwrkr )
                    ! generate q in a
                    ! workspace: need   n*n [r] + n [tau] + n    [work]
                    ! workspace: prefer n*n [r] + n [tau] + n*nb [work]
                    call stdlib_dorgqr( m, n, n, a, lda, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ie = itau
                    itauq = ie + n
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in work(ir)
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n      [work]
                    ! workspace: prefer n*n [r] + 3*n [e, tauq, taup] + 2*n*nb [work]
                    call stdlib_dgebrd( n, n, work( ir ), ldwrkr, s, work( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! work(iu) is n by n
                    iu = nwork
                    nwork = iu + n*n
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in work(iu) and computing right
                    ! singular vectors of bidiagonal matrix in vt
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n*n [u] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', n, s, work( ie ), work( iu ), n,vt, ldvt, dum, &
                              idum, work( nwork ), iwork,info )
                    ! overwrite work(iu) by left singular vectors of r
                    ! and vt by right singular vectors of r
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n*n [u] + n    [work]
                    ! workspace: prefer n*n [r] + 3*n [e, tauq, taup] + n*n [u] + n*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', n, n, n, work( ir ), ldwrkr,work( itauq ), &
                              work( iu ), n, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', n, n, n, work( ir ), ldwrkr,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! multiply q in a by left singular vectors of r in
                    ! work(iu), storing result in work(ir) and copying to a
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n*n [u]
                    ! workspace: prefer m*n [r] + 3*n [e, tauq, taup] + n*n [u]
                    do i = 1, m, ldwrkr
                       chunk = min( m - i + 1_ilp, ldwrkr )
                       call stdlib_dgemm( 'N', 'N', chunk, n, n, one, a( i, 1_ilp ),lda, work( iu ), &
                                 n, zero, work( ir ),ldwrkr )
                       call stdlib_dlacpy( 'F', chunk, n, work( ir ), ldwrkr,a( i, 1_ilp ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 3 (m >> n, jobz='s')
                    ! n left singular vectors to be computed in u and
                    ! n right singular vectors to be computed in vt
                    ir = 1_ilp
                    ! work(ir) is n by n
                    ldwrkr = n
                    itau = ir + ldwrkr*n
                    nwork = itau + n
                    ! compute a=q*r
                    ! workspace: need   n*n [r] + n [tau] + n    [work]
                    ! workspace: prefer n*n [r] + n [tau] + n*nb [work]
                    call stdlib_dgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! copy r to work(ir), zeroing out below it
                    call stdlib_dlacpy( 'U', n, n, a, lda, work( ir ), ldwrkr )
                    call stdlib_dlaset( 'L', n - 1_ilp, n - 1_ilp, zero, zero, work(ir+1),ldwrkr )
                    ! generate q in a
                    ! workspace: need   n*n [r] + n [tau] + n    [work]
                    ! workspace: prefer n*n [r] + n [tau] + n*nb [work]
                    call stdlib_dorgqr( m, n, n, a, lda, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ie = itau
                    itauq = ie + n
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in work(ir)
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n      [work]
                    ! workspace: prefer n*n [r] + 3*n [e, tauq, taup] + 2*n*nb [work]
                    call stdlib_dgebrd( n, n, work( ir ), ldwrkr, s, work( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagoal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', n, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! overwrite u by left singular vectors of r and vt
                    ! by right singular vectors of r
                    ! workspace: need   n*n [r] + 3*n [e, tauq, taup] + n    [work]
                    ! workspace: prefer n*n [r] + 3*n [e, tauq, taup] + n*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', n, n, n, work( ir ), ldwrkr,work( itauq ), &
                              u, ldu, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', n, n, n, work( ir ), ldwrkr,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! multiply q in a by left singular vectors of r in
                    ! work(ir), storing result in u
                    ! workspace: need   n*n [r]
                    call stdlib_dlacpy( 'F', n, n, u, ldu, work( ir ), ldwrkr )
                    call stdlib_dgemm( 'N', 'N', m, n, n, one, a, lda, work( ir ),ldwrkr, zero, u,&
                               ldu )
                 else if( wntqa ) then
                    ! path 4 (m >> n, jobz='a')
                    ! m left singular vectors to be computed in u and
                    ! n right singular vectors to be computed in vt
                    iu = 1_ilp
                    ! work(iu) is n by n
                    ldwrku = n
                    itau = iu + ldwrku*n
                    nwork = itau + n
                    ! compute a=q*r, copying result to u
                    ! workspace: need   n*n [u] + n [tau] + n    [work]
                    ! workspace: prefer n*n [u] + n [tau] + n*nb [work]
                    call stdlib_dgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    call stdlib_dlacpy( 'L', m, n, a, lda, u, ldu )
                    ! generate q in u
                    ! workspace: need   n*n [u] + n [tau] + m    [work]
                    ! workspace: prefer n*n [u] + n [tau] + m*nb [work]
                    call stdlib_dorgqr( m, m, n, u, ldu, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ! produce r in a, zeroing out other entries
                    if (n>1_ilp) call stdlib_dlaset( 'L', n-1, n-1, zero, zero, a( 2_ilp, 1_ilp ), lda )
                    ie = itau
                    itauq = ie + n
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in a
                    ! workspace: need   n*n [u] + 3*n [e, tauq, taup] + n      [work]
                    ! workspace: prefer n*n [u] + 3*n [e, tauq, taup] + 2*n*nb [work]
                    call stdlib_dgebrd( n, n, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                              work( nwork ), lwork-nwork+1,ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in work(iu) and computing right
                    ! singular vectors of bidiagonal matrix in vt
                    ! workspace: need   n*n [u] + 3*n [e, tauq, taup] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', n, s, work( ie ), work( iu ), n,vt, ldvt, dum, &
                              idum, work( nwork ), iwork,info )
                    ! overwrite work(iu) by left singular vectors of r and vt
                    ! by right singular vectors of r
                    ! workspace: need   n*n [u] + 3*n [e, tauq, taup] + n    [work]
                    ! workspace: prefer n*n [u] + 3*n [e, tauq, taup] + n*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', n, n, n, a, lda,work( itauq ), work( iu ), &
                              ldwrku,work( nwork ), lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! multiply q in u by left singular vectors of r in
                    ! work(iu), storing result in a
                    ! workspace: need   n*n [u]
                    call stdlib_dgemm( 'N', 'N', m, n, n, one, u, ldu, work( iu ),ldwrku, zero, a,&
                               lda )
                    ! copy left singular vectors of a from a to u
                    call stdlib_dlacpy( 'F', m, n, a, lda, u, ldu )
                 end if
              else
                 ! m < mnthr
                 ! path 5 (m >= n, but not much larger)
                 ! reduce to bidiagonal form without qr decomposition
                 ie = 1_ilp
                 itauq = ie + n
                 itaup = itauq + n
                 nwork = itaup + n
                 ! bidiagonalize a
                 ! workspace: need   3*n [e, tauq, taup] + m        [work]
                 ! workspace: prefer 3*n [e, tauq, taup] + (m+n)*nb [work]
                 call stdlib_dgebrd( m, n, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 5n (m >= n, jobz='n')
                    ! perform bidiagonal svd, only computing singular values
                    ! workspace: need   3*n [e, tauq, taup] + bdspac
                    call stdlib_dbdsdc( 'U', 'N', n, s, work( ie ), dum, 1_ilp, dum, 1_ilp,dum, idum, &
                              work( nwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 5o (m >= n, jobz='o')
                    iu = nwork
                    if( lwork >= m*n + 3_ilp*n + bdspac ) then
                       ! work( iu ) is m by n
                       ldwrku = m
                       nwork = iu + ldwrku*n
                       call stdlib_dlaset( 'F', m, n, zero, zero, work( iu ),ldwrku )
                       ! ir is unused; silence compile warnings
                       ir = -1_ilp
                    else
                       ! work( iu ) is n by n
                       ldwrku = n
                       nwork = iu + ldwrku*n
                       ! work(ir) is ldwrkr by n
                       ir = nwork
                       ldwrkr = ( lwork - n*n - 3_ilp*n ) / n
                    end if
                    nwork = iu + ldwrku*n
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in work(iu) and computing right
                    ! singular vectors of bidiagonal matrix in vt
                    ! workspace: need   3*n [e, tauq, taup] + n*n [u] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', n, s, work( ie ), work( iu ),ldwrku, vt, ldvt, &
                              dum, idum, work( nwork ),iwork, info )
                    ! overwrite vt by right singular vectors of a
                    ! workspace: need   3*n [e, tauq, taup] + n*n [u] + n    [work]
                    ! workspace: prefer 3*n [e, tauq, taup] + n*n [u] + n*nb [work]
                    call stdlib_dormbr( 'P', 'R', 'T', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    if( lwork >= m*n + 3_ilp*n + bdspac ) then
                       ! path 5o-fast
                       ! overwrite work(iu) by left singular vectors of a
                       ! workspace: need   3*n [e, tauq, taup] + m*n [u] + n    [work]
                       ! workspace: prefer 3*n [e, tauq, taup] + m*n [u] + n*nb [work]
                       call stdlib_dormbr( 'Q', 'L', 'N', m, n, n, a, lda,work( itauq ), work( iu &
                                 ), ldwrku,work( nwork ), lwork - nwork + 1_ilp, ierr )
                       ! copy left singular vectors of a from work(iu) to a
                       call stdlib_dlacpy( 'F', m, n, work( iu ), ldwrku, a, lda )
                    else
                       ! path 5o-slow
                       ! generate q in a
                       ! workspace: need   3*n [e, tauq, taup] + n*n [u] + n    [work]
                       ! workspace: prefer 3*n [e, tauq, taup] + n*n [u] + n*nb [work]
                       call stdlib_dorgbr( 'Q', m, n, n, a, lda, work( itauq ),work( nwork ), &
                                 lwork - nwork + 1_ilp, ierr )
                       ! multiply q in a by left singular vectors of
                       ! bidiagonal matrix in work(iu), storing result in
                       ! work(ir) and copying to a
                       ! workspace: need   3*n [e, tauq, taup] + n*n [u] + nb*n [r]
                       ! workspace: prefer 3*n [e, tauq, taup] + n*n [u] + m*n  [r]
                       do i = 1, m, ldwrkr
                          chunk = min( m - i + 1_ilp, ldwrkr )
                          call stdlib_dgemm( 'N', 'N', chunk, n, n, one, a( i, 1_ilp ),lda, work( iu )&
                                    , ldwrku, zero,work( ir ), ldwrkr )
                          call stdlib_dlacpy( 'F', chunk, n, work( ir ), ldwrkr,a( i, 1_ilp ), lda )
                                    
                       end do
                    end if
                 else if( wntqs ) then
                    ! path 5s (m >= n, jobz='s')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   3*n [e, tauq, taup] + bdspac
                    call stdlib_dlaset( 'F', m, n, zero, zero, u, ldu )
                    call stdlib_dbdsdc( 'U', 'I', n, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! overwrite u by left singular vectors of a and vt
                    ! by right singular vectors of a
                    ! workspace: need   3*n [e, tauq, taup] + n    [work]
                    ! workspace: prefer 3*n [e, tauq, taup] + n*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', m, n, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                 else if( wntqa ) then
                    ! path 5a (m >= n, jobz='a')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   3*n [e, tauq, taup] + bdspac
                    call stdlib_dlaset( 'F', m, m, zero, zero, u, ldu )
                    call stdlib_dbdsdc( 'U', 'I', n, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! set the right corner of u to identity matrix
                    if( m>n ) then
                       call stdlib_dlaset( 'F', m - n, m - n, zero, one, u(n+1,n+1),ldu )
                    end if
                    ! overwrite u by left singular vectors of a and vt
                    ! by right singular vectors of a
                    ! workspace: need   3*n [e, tauq, taup] + m    [work]
                    ! workspace: prefer 3*n [e, tauq, taup] + m*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', n, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                 end if
              end if
           else
              ! a has more columns than rows. if a has sufficiently more
              ! columns than rows, first reduce using the lq decomposition (if
              ! sufficient workspace available)
              if( n>=mnthr ) then
                 if( wntqn ) then
                    ! path 1t (n >> m, jobz='n')
                    ! no singular vectors to be computed
                    itau = 1_ilp
                    nwork = itau + m
                    ! compute a=l*q
                    ! workspace: need   m [tau] + m [work]
                    ! workspace: prefer m [tau] + m*nb [work]
                    call stdlib_dgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! zero out above l
                    if (m>1_ilp) call stdlib_dlaset( 'U', m-1, m-1, zero, zero, a( 1_ilp, 2_ilp ), lda )
                    ie = 1_ilp
                    itauq = ie + m
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in a
                    ! workspace: need   3*m [e, tauq, taup] + m      [work]
                    ! workspace: prefer 3*m [e, tauq, taup] + 2*m*nb [work]
                    call stdlib_dgebrd( m, m, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                              work( nwork ), lwork-nwork+1,ierr )
                    nwork = ie + m
                    ! perform bidiagonal svd, computing singular values only
                    ! workspace: need   m [e] + bdspac
                    call stdlib_dbdsdc( 'U', 'N', m, s, work( ie ), dum, 1_ilp, dum, 1_ilp,dum, idum, &
                              work( nwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 2t (n >> m, jobz='o')
                    ! m right singular vectors to be overwritten on a and
                    ! m left singular vectors to be computed in u
                    ivt = 1_ilp
                    ! work(ivt) is m by m
                    ! work(il)  is m by m; it is later resized to m by chunk for gemm
                    il = ivt + m*m
                    if( lwork >= m*n + m*m + 3_ilp*m + bdspac ) then
                       ldwrkl = m
                       chunk = n
                    else
                       ldwrkl = m
                       chunk = ( lwork - m*m ) / m
                    end if
                    itau = il + ldwrkl*m
                    nwork = itau + m
                    ! compute a=l*q
                    ! workspace: need   m*m [vt] + m*m [l] + m [tau] + m    [work]
                    ! workspace: prefer m*m [vt] + m*m [l] + m [tau] + m*nb [work]
                    call stdlib_dgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! copy l to work(il), zeroing about above it
                    call stdlib_dlacpy( 'L', m, m, a, lda, work( il ), ldwrkl )
                    call stdlib_dlaset( 'U', m - 1_ilp, m - 1_ilp, zero, zero,work( il + ldwrkl ), ldwrkl &
                              )
                    ! generate q in a
                    ! workspace: need   m*m [vt] + m*m [l] + m [tau] + m    [work]
                    ! workspace: prefer m*m [vt] + m*m [l] + m [tau] + m*nb [work]
                    call stdlib_dorglq( m, n, m, a, lda, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ie = itau
                    itauq = ie + m
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in work(il)
                    ! workspace: need   m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + m      [work]
                    ! workspace: prefer m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + 2*m*nb [work]
                    call stdlib_dgebrd( m, m, work( il ), ldwrkl, s, work( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u, and computing right singular
                    ! vectors of bidiagonal matrix in work(ivt)
                    ! workspace: need   m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', m, s, work( ie ), u, ldu,work( ivt ), m, dum, &
                              idum, work( nwork ),iwork, info )
                    ! overwrite u by left singular vectors of l and work(ivt)
                    ! by right singular vectors of l
                    ! workspace: need   m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + m    [work]
                    ! workspace: prefer m*m [vt] + m*m [l] + 3*m [e, tauq, taup] + m*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', m, m, m, work( il ), ldwrkl,work( itauq ), &
                              u, ldu, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', m, m, m, work( il ), ldwrkl,work( itaup ), &
                              work( ivt ), m,work( nwork ), lwork - nwork + 1_ilp, ierr )
                    ! multiply right singular vectors of l in work(ivt) by q
                    ! in a, storing result in work(il) and copying to a
                    ! workspace: need   m*m [vt] + m*m [l]
                    ! workspace: prefer m*m [vt] + m*n [l]
                    ! at this point, l is resized as m by chunk.
                    do i = 1, n, chunk
                       blk = min( n - i + 1_ilp, chunk )
                       call stdlib_dgemm( 'N', 'N', m, blk, m, one, work( ivt ), m,a( 1_ilp, i ), lda,&
                                  zero, work( il ), ldwrkl )
                       call stdlib_dlacpy( 'F', m, blk, work( il ), ldwrkl,a( 1_ilp, i ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 3t (n >> m, jobz='s')
                    ! m right singular vectors to be computed in vt and
                    ! m left singular vectors to be computed in u
                    il = 1_ilp
                    ! work(il) is m by m
                    ldwrkl = m
                    itau = il + ldwrkl*m
                    nwork = itau + m
                    ! compute a=l*q
                    ! workspace: need   m*m [l] + m [tau] + m    [work]
                    ! workspace: prefer m*m [l] + m [tau] + m*nb [work]
                    call stdlib_dgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    ! copy l to work(il), zeroing out above it
                    call stdlib_dlacpy( 'L', m, m, a, lda, work( il ), ldwrkl )
                    call stdlib_dlaset( 'U', m - 1_ilp, m - 1_ilp, zero, zero,work( il + ldwrkl ), ldwrkl &
                              )
                    ! generate q in a
                    ! workspace: need   m*m [l] + m [tau] + m    [work]
                    ! workspace: prefer m*m [l] + m [tau] + m*nb [work]
                    call stdlib_dorglq( m, n, m, a, lda, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ie = itau
                    itauq = ie + m
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in work(iu).
                    ! workspace: need   m*m [l] + 3*m [e, tauq, taup] + m      [work]
                    ! workspace: prefer m*m [l] + 3*m [e, tauq, taup] + 2*m*nb [work]
                    call stdlib_dgebrd( m, m, work( il ), ldwrkl, s, work( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   m*m [l] + 3*m [e, tauq, taup] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', m, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! overwrite u by left singular vectors of l and vt
                    ! by right singular vectors of l
                    ! workspace: need   m*m [l] + 3*m [e, tauq, taup] + m    [work]
                    ! workspace: prefer m*m [l] + 3*m [e, tauq, taup] + m*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', m, m, m, work( il ), ldwrkl,work( itauq ), &
                              u, ldu, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', m, m, m, work( il ), ldwrkl,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork - nwork + 1_ilp, ierr )
                    ! multiply right singular vectors of l in work(il) by
                    ! q in a, storing result in vt
                    ! workspace: need   m*m [l]
                    call stdlib_dlacpy( 'F', m, m, vt, ldvt, work( il ), ldwrkl )
                    call stdlib_dgemm( 'N', 'N', m, n, m, one, work( il ), ldwrkl,a, lda, zero, &
                              vt, ldvt )
                 else if( wntqa ) then
                    ! path 4t (n >> m, jobz='a')
                    ! n right singular vectors to be computed in vt and
                    ! m left singular vectors to be computed in u
                    ivt = 1_ilp
                    ! work(ivt) is m by m
                    ldwkvt = m
                    itau = ivt + ldwkvt*m
                    nwork = itau + m
                    ! compute a=l*q, copying result to vt
                    ! workspace: need   m*m [vt] + m [tau] + m    [work]
                    ! workspace: prefer m*m [vt] + m [tau] + m*nb [work]
                    call stdlib_dgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork - nwork + &
                              1_ilp, ierr )
                    call stdlib_dlacpy( 'U', m, n, a, lda, vt, ldvt )
                    ! generate q in vt
                    ! workspace: need   m*m [vt] + m [tau] + n    [work]
                    ! workspace: prefer m*m [vt] + m [tau] + n*nb [work]
                    call stdlib_dorglq( n, n, m, vt, ldvt, work( itau ),work( nwork ), lwork - &
                              nwork + 1_ilp, ierr )
                    ! produce l in a, zeroing out other entries
                    if (m>1_ilp) call stdlib_dlaset( 'U', m-1, m-1, zero, zero, a( 1_ilp, 2_ilp ), lda )
                    ie = itau
                    itauq = ie + m
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in a
                    ! workspace: need   m*m [vt] + 3*m [e, tauq, taup] + m      [work]
                    ! workspace: prefer m*m [vt] + 3*m [e, tauq, taup] + 2*m*nb [work]
                    call stdlib_dgebrd( m, m, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                              work( nwork ), lwork-nwork+1,ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in work(ivt)
                    ! workspace: need   m*m [vt] + 3*m [e, tauq, taup] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', m, s, work( ie ), u, ldu,work( ivt ), ldwkvt, &
                              dum, idum,work( nwork ), iwork, info )
                    ! overwrite u by left singular vectors of l and work(ivt)
                    ! by right singular vectors of l
                    ! workspace: need   m*m [vt] + 3*m [e, tauq, taup]+ m    [work]
                    ! workspace: prefer m*m [vt] + 3*m [e, tauq, taup]+ m*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', m, m, m, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', m, m, m, a, lda,work( itaup ), work( ivt ),&
                               ldwkvt,work( nwork ), lwork - nwork + 1_ilp, ierr )
                    ! multiply right singular vectors of l in work(ivt) by
                    ! q in vt, storing result in a
                    ! workspace: need   m*m [vt]
                    call stdlib_dgemm( 'N', 'N', m, n, m, one, work( ivt ), ldwkvt,vt, ldvt, zero,&
                               a, lda )
                    ! copy right singular vectors of a from a to vt
                    call stdlib_dlacpy( 'F', m, n, a, lda, vt, ldvt )
                 end if
              else
                 ! n < mnthr
                 ! path 5t (n > m, but not much larger)
                 ! reduce to bidiagonal form without lq decomposition
                 ie = 1_ilp
                 itauq = ie + m
                 itaup = itauq + m
                 nwork = itaup + m
                 ! bidiagonalize a
                 ! workspace: need   3*m [e, tauq, taup] + n        [work]
                 ! workspace: prefer 3*m [e, tauq, taup] + (m+n)*nb [work]
                 call stdlib_dgebrd( m, n, a, lda, s, work( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 5tn (n > m, jobz='n')
                    ! perform bidiagonal svd, only computing singular values
                    ! workspace: need   3*m [e, tauq, taup] + bdspac
                    call stdlib_dbdsdc( 'L', 'N', m, s, work( ie ), dum, 1_ilp, dum, 1_ilp,dum, idum, &
                              work( nwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 5to (n > m, jobz='o')
                    ldwkvt = m
                    ivt = nwork
                    if( lwork >= m*n + 3_ilp*m + bdspac ) then
                       ! work( ivt ) is m by n
                       call stdlib_dlaset( 'F', m, n, zero, zero, work( ivt ),ldwkvt )
                       nwork = ivt + ldwkvt*n
                       ! il is unused; silence compile warnings
                       il = -1_ilp
                    else
                       ! work( ivt ) is m by m
                       nwork = ivt + ldwkvt*m
                       il = nwork
                       ! work(il) is m by chunk
                       chunk = ( lwork - m*m - 3_ilp*m ) / m
                    end if
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in work(ivt)
                    ! workspace: need   3*m [e, tauq, taup] + m*m [vt] + bdspac
                    call stdlib_dbdsdc( 'L', 'I', m, s, work( ie ), u, ldu,work( ivt ), ldwkvt, &
                              dum, idum,work( nwork ), iwork, info )
                    ! overwrite u by left singular vectors of a
                    ! workspace: need   3*m [e, tauq, taup] + m*m [vt] + m    [work]
                    ! workspace: prefer 3*m [e, tauq, taup] + m*m [vt] + m*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    if( lwork >= m*n + 3_ilp*m + bdspac ) then
                       ! path 5to-fast
                       ! overwrite work(ivt) by left singular vectors of a
                       ! workspace: need   3*m [e, tauq, taup] + m*n [vt] + m    [work]
                       ! workspace: prefer 3*m [e, tauq, taup] + m*n [vt] + m*nb [work]
                       call stdlib_dormbr( 'P', 'R', 'T', m, n, m, a, lda,work( itaup ), work( &
                                 ivt ), ldwkvt,work( nwork ), lwork - nwork + 1_ilp, ierr )
                       ! copy right singular vectors of a from work(ivt) to a
                       call stdlib_dlacpy( 'F', m, n, work( ivt ), ldwkvt, a, lda )
                    else
                       ! path 5to-slow
                       ! generate p**t in a
                       ! workspace: need   3*m [e, tauq, taup] + m*m [vt] + m    [work]
                       ! workspace: prefer 3*m [e, tauq, taup] + m*m [vt] + m*nb [work]
                       call stdlib_dorgbr( 'P', m, n, m, a, lda, work( itaup ),work( nwork ), &
                                 lwork - nwork + 1_ilp, ierr )
                       ! multiply q in a by right singular vectors of
                       ! bidiagonal matrix in work(ivt), storing result in
                       ! work(il) and copying to a
                       ! workspace: need   3*m [e, tauq, taup] + m*m [vt] + m*nb [l]
                       ! workspace: prefer 3*m [e, tauq, taup] + m*m [vt] + m*n  [l]
                       do i = 1, n, chunk
                          blk = min( n - i + 1_ilp, chunk )
                          call stdlib_dgemm( 'N', 'N', m, blk, m, one, work( ivt ),ldwkvt, a( 1_ilp, &
                                    i ), lda, zero,work( il ), m )
                          call stdlib_dlacpy( 'F', m, blk, work( il ), m, a( 1_ilp, i ),lda )
                       end do
                    end if
                 else if( wntqs ) then
                    ! path 5ts (n > m, jobz='s')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   3*m [e, tauq, taup] + bdspac
                    call stdlib_dlaset( 'F', m, n, zero, zero, vt, ldvt )
                    call stdlib_dbdsdc( 'L', 'I', m, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! overwrite u by left singular vectors of a and vt
                    ! by right singular vectors of a
                    ! workspace: need   3*m [e, tauq, taup] + m    [work]
                    ! workspace: prefer 3*m [e, tauq, taup] + m*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', m, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                 else if( wntqa ) then
                    ! path 5ta (n > m, jobz='a')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in u and computing right singular
                    ! vectors of bidiagonal matrix in vt
                    ! workspace: need   3*m [e, tauq, taup] + bdspac
                    call stdlib_dlaset( 'F', n, n, zero, zero, vt, ldvt )
                    call stdlib_dbdsdc( 'L', 'I', m, s, work( ie ), u, ldu, vt,ldvt, dum, idum, &
                              work( nwork ), iwork,info )
                    ! set the right corner of vt to identity matrix
                    if( n>m ) then
                       call stdlib_dlaset( 'F', n-m, n-m, zero, one, vt(m+1,m+1),ldvt )
                    end if
                    ! overwrite u by left singular vectors of a and vt
                    ! by right singular vectors of a
                    ! workspace: need   3*m [e, tauq, taup] + n    [work]
                    ! workspace: prefer 3*m [e, tauq, taup] + n*nb [work]
                    call stdlib_dormbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                    call stdlib_dormbr( 'P', 'R', 'T', n, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork - nwork + 1_ilp, ierr )
                 end if
              end if
           end if
           ! undo scaling if necessary
           if( iscl==1_ilp ) then
              if( anrm>bignum )call stdlib_dlascl( 'G', 0_ilp, 0_ilp, bignum, anrm, minmn, 1_ilp, s, minmn,&
                        ierr )
              if( anrm<smlnum )call stdlib_dlascl( 'G', 0_ilp, 0_ilp, smlnum, anrm, minmn, 1_ilp, s, minmn,&
                        ierr )
           end if
           ! return optimal workspace in work(1)
           work( 1_ilp ) = stdlib_droundup_lwork( maxwrk )
           return
     end subroutine stdlib_dgesdd


     module subroutine stdlib_cgesdd( jobz, m, n, a, lda, s, u, ldu, vt, ldvt,work, lwork, rwork, iwork, &
     !! CGESDD computes the singular value decomposition (SVD) of a complex
     !! M-by-N matrix A, optionally computing the left and/or right singular
     !! vectors, by using divide-and-conquer method. The SVD is written
     !! A = U * SIGMA * conjugate-transpose(V)
     !! where SIGMA is an M-by-N matrix which is zero except for its
     !! min(m,n) diagonal elements, U is an M-by-M unitary matrix, and
     !! V is an N-by-N unitary matrix.  The diagonal elements of SIGMA
     !! are the singular values of A; they are real and non-negative, and
     !! are returned in descending order.  The first min(m,n) columns of
     !! U and V are the left and right singular vectors of A.
     !! Note that the routine returns VT = V**H, not V.
     !! The divide and conquer algorithm makes very mild assumptions about
     !! floating point arithmetic. It will work on machines with a guard
     !! digit in add/subtract, or on those binary machines without guard
     !! digits which subtract like the Cray X-MP, Cray Y-MP, Cray C-90, or
     !! Cray-2. It could conceivably fail on hexadecimal or decimal machines
     !! without guard digits, but we know of none.
               info )
        ! -- lapack driver routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_sp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           character, intent(in) :: jobz
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldu, ldvt, lwork, m, n
           ! Array Arguments 
           integer(ilp), intent(out) :: iwork(*)
           real(sp), intent(out) :: rwork(*), s(*)
           complex(sp), intent(inout) :: a(lda,*)
           complex(sp), intent(out) :: u(ldu,*), vt(ldvt,*), work(*)
        ! =====================================================================
           
           
           ! Local Scalars 
           logical(lk) :: lquery, wntqa, wntqas, wntqn, wntqo, wntqs
           integer(ilp) :: blk, chunk, i, ie, ierr, il, ir, iru, irvt, iscl, itau, itaup, itauq, &
           iu, ivt, ldwkvt, ldwrkl, ldwrkr, ldwrku, maxwrk, minmn, minwrk, mnthr1, mnthr2, nrwork,&
                      nwork, wrkbl
           integer(ilp) :: lwork_cgebrd_mn, lwork_cgebrd_mm, lwork_cgebrd_nn, lwork_cgelqf_mn, &
           lwork_cgeqrf_mn, lwork_cungbr_p_mn, lwork_cungbr_p_nn, lwork_cungbr_q_mn, &
           lwork_cungbr_q_mm, lwork_cunglq_mn, lwork_cunglq_nn, lwork_cungqr_mm, lwork_cungqr_mn, &
           lwork_cunmbr_prc_mm, lwork_cunmbr_qln_mm, lwork_cunmbr_prc_mn, lwork_cunmbr_qln_mn, &
                     lwork_cunmbr_prc_nn, lwork_cunmbr_qln_nn
           real(sp) :: anrm, bignum, eps, smlnum
           ! Local Arrays 
           integer(ilp) :: idum(1_ilp)
           real(sp) :: dum(1_ilp)
           complex(sp) :: cdum(1_ilp)
           ! Intrinsic Functions 
           ! Executable Statements 
           ! test the input arguments
           info   = 0_ilp
           minmn  = min( m, n )
           mnthr1 = int( minmn*17.0_sp / 9.0_sp,KIND=ilp)
           mnthr2 = int( minmn*5.0_sp / 3.0_sp,KIND=ilp)
           wntqa  = stdlib_lsame( jobz, 'A' )
           wntqs  = stdlib_lsame( jobz, 'S' )
           wntqas = wntqa .or. wntqs
           wntqo  = stdlib_lsame( jobz, 'O' )
           wntqn  = stdlib_lsame( jobz, 'N' )
           lquery = ( lwork==-1_ilp )
           minwrk = 1_ilp
           maxwrk = 1_ilp
           if( .not.( wntqa .or. wntqs .or. wntqo .or. wntqn ) ) then
              info = -1_ilp
           else if( m<0_ilp ) then
              info = -2_ilp
           else if( n<0_ilp ) then
              info = -3_ilp
           else if( lda<max( 1_ilp, m ) ) then
              info = -5_ilp
           else if( ldu<1_ilp .or. ( wntqas .and. ldu<m ) .or.( wntqo .and. m<n .and. ldu<m ) ) &
                     then
              info = -8_ilp
           else if( ldvt<1_ilp .or. ( wntqa .and. ldvt<n ) .or.( wntqs .and. ldvt<minmn ) .or.( wntqo &
                     .and. m>=n .and. ldvt<n ) ) then
              info = -10_ilp
           end if
           ! compute workspace
             ! note: comments in the code beginning "workspace:" describe the
             ! minimal amount of workspace allocated at that point in the code,
             ! as well as the preferred amount for good performance.
             ! cworkspace refers to complex workspace, and rworkspace to
             ! real workspace. nb refers to the optimal block size for the
             ! immediately following subroutine, as returned by stdlib_ilaenv.)
           if( info==0_ilp ) then
              minwrk = 1_ilp
              maxwrk = 1_ilp
              if( m>=n .and. minmn>0_ilp ) then
                 ! there is no complex work space needed for bidiagonal svd
                 ! the realwork space needed for bidiagonal svd (stdlib_sbdsdc,KIND=sp) is
                 ! bdspac = 3*n*n + 4*n for singular values and vectors;
                 ! bdspac = 4*n         for singular values only;
                 ! not including e, ru, and rvt matrices.
                 ! compute space preferred for each routine
                 call stdlib_cgebrd( m, n, cdum(1_ilp), m, dum(1_ilp), dum(1_ilp), cdum(1_ilp),cdum(1_ilp), cdum(1_ilp), -&
                           1_ilp, ierr )
                 lwork_cgebrd_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cgebrd( n, n, cdum(1_ilp), n, dum(1_ilp), dum(1_ilp), cdum(1_ilp),cdum(1_ilp), cdum(1_ilp), -&
                           1_ilp, ierr )
                 lwork_cgebrd_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cgeqrf( m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp), -1_ilp, ierr )
                 lwork_cgeqrf_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cungbr( 'P', n, n, n, cdum(1_ilp), n, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cungbr_p_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cungbr( 'Q', m, m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cungbr_q_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cungbr( 'Q', m, n, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cungbr_q_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cungqr( m, m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cungqr_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cungqr( m, n, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cungqr_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunmbr( 'P', 'R', 'C', n, n, n, cdum(1_ilp), n, cdum(1_ilp),cdum(1_ilp), n, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_cunmbr_prc_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunmbr( 'Q', 'L', 'N', m, m, n, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_cunmbr_qln_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunmbr( 'Q', 'L', 'N', m, n, n, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_cunmbr_qln_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunmbr( 'Q', 'L', 'N', n, n, n, cdum(1_ilp), n, cdum(1_ilp),cdum(1_ilp), n, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_cunmbr_qln_nn = int( cdum(1_ilp),KIND=ilp)
                 if( m>=mnthr1 ) then
                    if( wntqn ) then
                       ! path 1 (m >> n, jobz='n')
                       maxwrk = n + lwork_cgeqrf_mn
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cgebrd_nn )
                       minwrk = 3_ilp*n
                    else if( wntqo ) then
                       ! path 2 (m >> n, jobz='o')
                       wrkbl = n + lwork_cgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_cungqr_mn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cgebrd_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cunmbr_qln_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cunmbr_prc_nn )
                       maxwrk = m*n + n*n + wrkbl
                       minwrk = 2_ilp*n*n + 3_ilp*n
                    else if( wntqs ) then
                       ! path 3 (m >> n, jobz='s')
                       wrkbl = n + lwork_cgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_cungqr_mn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cgebrd_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cunmbr_qln_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cunmbr_prc_nn )
                       maxwrk = n*n + wrkbl
                       minwrk = n*n + 3_ilp*n
                    else if( wntqa ) then
                       ! path 4 (m >> n, jobz='a')
                       wrkbl = n + lwork_cgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_cungqr_mm )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cgebrd_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cunmbr_qln_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_cunmbr_prc_nn )
                       maxwrk = n*n + wrkbl
                       minwrk = n*n + max( 3_ilp*n, n + m )
                    end if
                 else if( m>=mnthr2 ) then
                    ! path 5 (m >> n, but not as much as mnthr1)
                    maxwrk = 2_ilp*n + lwork_cgebrd_mn
                    minwrk = 2_ilp*n + m
                    if( wntqo ) then
                       ! path 5o (m >> n, jobz='o')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cungbr_p_nn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cungbr_q_mn )
                       maxwrk = maxwrk + m*n
                       minwrk = minwrk + n*n
                    else if( wntqs ) then
                       ! path 5s (m >> n, jobz='s')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cungbr_p_nn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cungbr_q_mn )
                    else if( wntqa ) then
                       ! path 5a (m >> n, jobz='a')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cungbr_p_nn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cungbr_q_mm )
                    end if
                 else
                    ! path 6 (m >= n, but not much larger)
                    maxwrk = 2_ilp*n + lwork_cgebrd_mn
                    minwrk = 2_ilp*n + m
                    if( wntqo ) then
                       ! path 6o (m >= n, jobz='o')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cunmbr_prc_nn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cunmbr_qln_mn )
                       maxwrk = maxwrk + m*n
                       minwrk = minwrk + n*n
                    else if( wntqs ) then
                       ! path 6s (m >= n, jobz='s')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cunmbr_qln_mn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cunmbr_prc_nn )
                    else if( wntqa ) then
                       ! path 6a (m >= n, jobz='a')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cunmbr_qln_mm )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_cunmbr_prc_nn )
                    end if
                 end if
              else if( minmn>0_ilp ) then
                 ! there is no complex work space needed for bidiagonal svd
                 ! the realwork space needed for bidiagonal svd (stdlib_sbdsdc,KIND=sp) is
                 ! bdspac = 3*m*m + 4*m for singular values and vectors;
                 ! bdspac = 4*m         for singular values only;
                 ! not including e, ru, and rvt matrices.
                 ! compute space preferred for each routine
                 call stdlib_cgebrd( m, n, cdum(1_ilp), m, dum(1_ilp), dum(1_ilp), cdum(1_ilp),cdum(1_ilp), cdum(1_ilp), -&
                           1_ilp, ierr )
                 lwork_cgebrd_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cgebrd( m, m, cdum(1_ilp), m, dum(1_ilp), dum(1_ilp), cdum(1_ilp),cdum(1_ilp), cdum(1_ilp), -&
                           1_ilp, ierr )
                 lwork_cgebrd_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cgelqf( m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp), -1_ilp, ierr )
                 lwork_cgelqf_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cungbr( 'P', m, n, m, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cungbr_p_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cungbr( 'P', n, n, m, cdum(1_ilp), n, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cungbr_p_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cungbr( 'Q', m, m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cungbr_q_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunglq( m, n, m, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cunglq_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunglq( n, n, m, cdum(1_ilp), n, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_cunglq_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunmbr( 'P', 'R', 'C', m, m, m, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_cunmbr_prc_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunmbr( 'P', 'R', 'C', m, n, m, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_cunmbr_prc_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunmbr( 'P', 'R', 'C', n, n, m, cdum(1_ilp), n, cdum(1_ilp),cdum(1_ilp), n, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_cunmbr_prc_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_cunmbr( 'Q', 'L', 'N', m, m, m, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_cunmbr_qln_mm = int( cdum(1_ilp),KIND=ilp)
                 if( n>=mnthr1 ) then
                    if( wntqn ) then
                       ! path 1t (n >> m, jobz='n')
                       maxwrk = m + lwork_cgelqf_mn
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cgebrd_mm )
                       minwrk = 3_ilp*m
                    else if( wntqo ) then
                       ! path 2t (n >> m, jobz='o')
                       wrkbl = m + lwork_cgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_cunglq_mn )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cgebrd_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cunmbr_qln_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cunmbr_prc_mm )
                       maxwrk = m*n + m*m + wrkbl
                       minwrk = 2_ilp*m*m + 3_ilp*m
                    else if( wntqs ) then
                       ! path 3t (n >> m, jobz='s')
                       wrkbl = m + lwork_cgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_cunglq_mn )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cgebrd_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cunmbr_qln_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cunmbr_prc_mm )
                       maxwrk = m*m + wrkbl
                       minwrk = m*m + 3_ilp*m
                    else if( wntqa ) then
                       ! path 4t (n >> m, jobz='a')
                       wrkbl = m + lwork_cgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_cunglq_nn )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cgebrd_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cunmbr_qln_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_cunmbr_prc_mm )
                       maxwrk = m*m + wrkbl
                       minwrk = m*m + max( 3_ilp*m, m + n )
                    end if
                 else if( n>=mnthr2 ) then
                    ! path 5t (n >> m, but not as much as mnthr1)
                    maxwrk = 2_ilp*m + lwork_cgebrd_mn
                    minwrk = 2_ilp*m + n
                    if( wntqo ) then
                       ! path 5to (n >> m, jobz='o')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cungbr_q_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cungbr_p_mn )
                       maxwrk = maxwrk + m*n
                       minwrk = minwrk + m*m
                    else if( wntqs ) then
                       ! path 5ts (n >> m, jobz='s')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cungbr_q_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cungbr_p_mn )
                    else if( wntqa ) then
                       ! path 5ta (n >> m, jobz='a')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cungbr_q_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cungbr_p_nn )
                    end if
                 else
                    ! path 6t (n > m, but not much larger)
                    maxwrk = 2_ilp*m + lwork_cgebrd_mn
                    minwrk = 2_ilp*m + n
                    if( wntqo ) then
                       ! path 6to (n > m, jobz='o')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cunmbr_qln_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cunmbr_prc_mn )
                       maxwrk = maxwrk + m*n
                       minwrk = minwrk + m*m
                    else if( wntqs ) then
                       ! path 6ts (n > m, jobz='s')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cunmbr_qln_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cunmbr_prc_mn )
                    else if( wntqa ) then
                       ! path 6ta (n > m, jobz='a')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cunmbr_qln_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_cunmbr_prc_nn )
                    end if
                 end if
              end if
              maxwrk = max( maxwrk, minwrk )
           end if
           if( info==0_ilp ) then
              work( 1_ilp ) = stdlib_sroundup_lwork( maxwrk )
              if( lwork<minwrk .and. .not. lquery ) then
                 info = -12_ilp
              end if
           end if
           if( info/=0_ilp ) then
              call stdlib_xerbla( 'CGESDD', -info )
              return
           else if( lquery ) then
              return
           end if
           ! quick return if possible
           if( m==0_ilp .or. n==0_ilp ) then
              return
           end if
           ! get machine constants
           eps = stdlib_slamch( 'P' )
           smlnum = sqrt( stdlib_slamch( 'S' ) ) / eps
           bignum = one / smlnum
           ! scale a if max element outside range [smlnum,bignum]
           anrm = stdlib_clange( 'M', m, n, a, lda, dum )
           if( stdlib_sisnan ( anrm ) ) then
               info = -4_ilp
               return
           end if
           iscl = 0_ilp
           if( anrm>zero .and. anrm<smlnum ) then
              iscl = 1_ilp
              call stdlib_clascl( 'G', 0_ilp, 0_ilp, anrm, smlnum, m, n, a, lda, ierr )
           else if( anrm>bignum ) then
              iscl = 1_ilp
              call stdlib_clascl( 'G', 0_ilp, 0_ilp, anrm, bignum, m, n, a, lda, ierr )
           end if
           if( m>=n ) then
              ! a has at least as many rows as columns. if a has sufficiently
              ! more rows than columns, first reduce using the qr
              ! decomposition (if sufficient workspace available)
              if( m>=mnthr1 ) then
                 if( wntqn ) then
                    ! path 1 (m >> n, jobz='n')
                    ! no singular vectors to be computed
                    itau = 1_ilp
                    nwork = itau + n
                    ! compute a=q*r
                    ! cworkspace: need   n [tau] + n    [work]
                    ! cworkspace: prefer n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! zero out below r
                    if (n>1_ilp) call stdlib_claset( 'L', n-1, n-1, czero, czero, a( 2_ilp, 1_ilp ),lda )
                    ie = 1_ilp
                    itauq = 1_ilp
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in a
                    ! cworkspace: need   2*n [tauq, taup] + n      [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + 2*n*nb [work]
                    ! rworkspace: need   n [e]
                    call stdlib_cgebrd( n, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ),&
                               work( nwork ), lwork-nwork+1,ierr )
                    nrwork = ie + n
                    ! perform bidiagonal svd, compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + bdspac
                    call stdlib_sbdsdc( 'U', 'N', n, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 2 (m >> n, jobz='o')
                    ! n left singular vectors to be overwritten on a and
                    ! n right singular vectors to be computed in vt
                    iu = 1_ilp
                    ! work(iu) is n by n
                    ldwrku = n
                    ir = iu + ldwrku*n
                    if( lwork >= m*n + n*n + 3_ilp*n ) then
                       ! work(ir) is m by n
                       ldwrkr = m
                    else
                       ldwrkr = ( lwork - n*n - 3_ilp*n ) / n
                    end if
                    itau = ir + ldwrkr*n
                    nwork = itau + n
                    ! compute a=q*r
                    ! cworkspace: need   n*n [u] + n*n [r] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! copy r to work( ir ), zeroing out below it
                    call stdlib_clacpy( 'U', n, n, a, lda, work( ir ), ldwrkr )
                    call stdlib_claset( 'L', n-1, n-1, czero, czero, work( ir+1 ),ldwrkr )
                    ! generate q in a
                    ! cworkspace: need   n*n [u] + n*n [r] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cungqr( m, n, n, a, lda, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in work(ir)
                    ! cworkspace: need   n*n [u] + n*n [r] + 2*n [tauq, taup] + n      [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + 2*n [tauq, taup] + 2*n*nb [work]
                    ! rworkspace: need   n [e]
                    call stdlib_cgebrd( n, n, work( ir ), ldwrkr, s, rwork( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of r in work(iru) and computing right singular vectors
                    ! of r in work(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = ie + n
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix work(iu)
                    ! overwrite work(iu) by the left singular vectors of r
                    ! cworkspace: need   n*n [u] + n*n [r] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', n, n, rwork( iru ), n, work( iu ),ldwrku )
                    call stdlib_cunmbr( 'Q', 'L', 'N', n, n, n, work( ir ), ldwrkr,work( itauq ), &
                              work( iu ), ldwrku,work( nwork ), lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by the right singular vectors of r
                    ! cworkspace: need   n*n [u] + n*n [r] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', n, n, n, work( ir ), ldwrkr,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork-nwork+1, ierr )
                    ! multiply q in a by left singular vectors of r in
                    ! work(iu), storing result in work(ir) and copying to a
                    ! cworkspace: need   n*n [u] + n*n [r]
                    ! cworkspace: prefer n*n [u] + m*n [r]
                    ! rworkspace: need   0
                    do i = 1, m, ldwrkr
                       chunk = min( m-i+1, ldwrkr )
                       call stdlib_cgemm( 'N', 'N', chunk, n, n, cone, a( i, 1_ilp ),lda, work( iu ), &
                                 ldwrku, czero,work( ir ), ldwrkr )
                       call stdlib_clacpy( 'F', chunk, n, work( ir ), ldwrkr,a( i, 1_ilp ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 3 (m >> n, jobz='s')
                    ! n left singular vectors to be computed in u and
                    ! n right singular vectors to be computed in vt
                    ir = 1_ilp
                    ! work(ir) is n by n
                    ldwrkr = n
                    itau = ir + ldwrkr*n
                    nwork = itau + n
                    ! compute a=q*r
                    ! cworkspace: need   n*n [r] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [r] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! copy r to work(ir), zeroing out below it
                    call stdlib_clacpy( 'U', n, n, a, lda, work( ir ), ldwrkr )
                    call stdlib_claset( 'L', n-1, n-1, czero, czero, work( ir+1 ),ldwrkr )
                    ! generate q in a
                    ! cworkspace: need   n*n [r] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [r] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cungqr( m, n, n, a, lda, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in work(ir)
                    ! cworkspace: need   n*n [r] + 2*n [tauq, taup] + n      [work]
                    ! cworkspace: prefer n*n [r] + 2*n [tauq, taup] + 2*n*nb [work]
                    ! rworkspace: need   n [e]
                    call stdlib_cgebrd( n, n, work( ir ), ldwrkr, s, rwork( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = ie + n
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix u
                    ! overwrite u by left singular vectors of r
                    ! cworkspace: need   n*n [r] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [r] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', n, n, rwork( iru ), n, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', n, n, n, work( ir ), ldwrkr,work( itauq ), &
                              u, ldu, work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by right singular vectors of r
                    ! cworkspace: need   n*n [r] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [r] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', n, n, n, work( ir ), ldwrkr,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork-nwork+1, ierr )
                    ! multiply q in a by left singular vectors of r in
                    ! work(ir), storing result in u
                    ! cworkspace: need   n*n [r]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'F', n, n, u, ldu, work( ir ), ldwrkr )
                    call stdlib_cgemm( 'N', 'N', m, n, n, cone, a, lda, work( ir ),ldwrkr, czero, &
                              u, ldu )
                 else if( wntqa ) then
                    ! path 4 (m >> n, jobz='a')
                    ! m left singular vectors to be computed in u and
                    ! n right singular vectors to be computed in vt
                    iu = 1_ilp
                    ! work(iu) is n by n
                    ldwrku = n
                    itau = iu + ldwrku*n
                    nwork = itau + n
                    ! compute a=q*r, copying result to u
                    ! cworkspace: need   n*n [u] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [u] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    call stdlib_clacpy( 'L', m, n, a, lda, u, ldu )
                    ! generate q in u
                    ! cworkspace: need   n*n [u] + n [tau] + m    [work]
                    ! cworkspace: prefer n*n [u] + n [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cungqr( m, m, n, u, ldu, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ! produce r in a, zeroing out below it
                    if (n>1_ilp) call stdlib_claset( 'L', n-1, n-1, czero, czero, a( 2_ilp, 1_ilp ),lda )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in a
                    ! cworkspace: need   n*n [u] + 2*n [tauq, taup] + n      [work]
                    ! cworkspace: prefer n*n [u] + 2*n [tauq, taup] + 2*n*nb [work]
                    ! rworkspace: need   n [e]
                    call stdlib_cgebrd( n, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ),&
                               work( nwork ), lwork-nwork+1,ierr )
                    iru = ie + n
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix work(iu)
                    ! overwrite work(iu) by left singular vectors of r
                    ! cworkspace: need   n*n [u] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [u] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', n, n, rwork( iru ), n, work( iu ),ldwrku )
                    call stdlib_cunmbr( 'Q', 'L', 'N', n, n, n, a, lda,work( itauq ), work( iu ), &
                              ldwrku,work( nwork ), lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by right singular vectors of r
                    ! cworkspace: need   n*n [u] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [u] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! multiply q in u by left singular vectors of r in
                    ! work(iu), storing result in a
                    ! cworkspace: need   n*n [u]
                    ! rworkspace: need   0
                    call stdlib_cgemm( 'N', 'N', m, n, n, cone, u, ldu, work( iu ),ldwrku, czero, &
                              a, lda )
                    ! copy left singular vectors of a from a to u
                    call stdlib_clacpy( 'F', m, n, a, lda, u, ldu )
                 end if
              else if( m>=mnthr2 ) then
                 ! mnthr2 <= m < mnthr1
                 ! path 5 (m >> n, but not as much as mnthr1)
                 ! reduce to bidiagonal form without qr decomposition, use
                 ! stdlib_cungbr and matrix multiplication to compute singular vectors
                 ie = 1_ilp
                 nrwork = ie + n
                 itauq = 1_ilp
                 itaup = itauq + n
                 nwork = itaup + n
                 ! bidiagonalize a
                 ! cworkspace: need   2*n [tauq, taup] + m        [work]
                 ! cworkspace: prefer 2*n [tauq, taup] + (m+n)*nb [work]
                 ! rworkspace: need   n [e]
                 call stdlib_cgebrd( m, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 5n (m >> n, jobz='n')
                    ! compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + bdspac
                    call stdlib_sbdsdc( 'U', 'N', n, s, rwork( ie ), dum, 1_ilp,dum,1_ilp,dum, idum, &
                              rwork( nrwork ), iwork, info )
                 else if( wntqo ) then
                    iu = nwork
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    ! path 5o (m >> n, jobz='o')
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'U', n, n, a, lda, vt, ldvt )
                    call stdlib_cungbr( 'P', n, n, n, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! generate q in a
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cungbr( 'Q', m, n, n, a, lda, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    if( lwork >= m*n + 3_ilp*n ) then
                       ! work( iu ) is m by n
                       ldwrku = m
                    else
                       ! work(iu) is ldwrku by n
                       ldwrku = ( lwork - 3_ilp*n ) / n
                    end if
                    nwork = iu + ldwrku*n
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply realmatrix rwork(irvt,KIND=sp) by p**h in vt,
                    ! storing the result in work(iu), copying to vt
                    ! cworkspace: need   2*n [tauq, taup] + n*n [u]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + 2*n*n [rwork]
                    call stdlib_clarcm( n, n, rwork( irvt ), n, vt, ldvt,work( iu ), ldwrku, &
                              rwork( nrwork ) )
                    call stdlib_clacpy( 'F', n, n, work( iu ), ldwrku, vt, ldvt )
                    ! multiply q in a by realmatrix rwork(iru,KIND=sp), storing the
                    ! result in work(iu), copying to a
                    ! cworkspace: need   2*n [tauq, taup] + n*n [u]
                    ! cworkspace: prefer 2*n [tauq, taup] + m*n [u]
                    ! rworkspace: need   n [e] + n*n [ru] + 2*n*n [rwork]
                    ! rworkspace: prefer n [e] + n*n [ru] + 2*m*n [rwork] < n + 5*n*n since m < 2*n here
                    nrwork = irvt
                    do i = 1, m, ldwrku
                       chunk = min( m-i+1, ldwrku )
                       call stdlib_clacrm( chunk, n, a( i, 1_ilp ), lda, rwork( iru ),n, work( iu ), &
                                 ldwrku, rwork( nrwork ) )
                       call stdlib_clacpy( 'F', chunk, n, work( iu ), ldwrku,a( i, 1_ilp ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 5s (m >> n, jobz='s')
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'U', n, n, a, lda, vt, ldvt )
                    call stdlib_cungbr( 'P', n, n, n, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! copy a to u, generate q
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'L', m, n, a, lda, u, ldu )
                    call stdlib_cungbr( 'Q', m, n, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply realmatrix rwork(irvt,KIND=sp) by p**h in vt,
                    ! storing the result in a, copying to vt
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + 2*n*n [rwork]
                    call stdlib_clarcm( n, n, rwork( irvt ), n, vt, ldvt, a, lda,rwork( nrwork ) )
                              
                    call stdlib_clacpy( 'F', n, n, a, lda, vt, ldvt )
                    ! multiply q in u by realmatrix rwork(iru,KIND=sp), storing the
                    ! result in a, copying to u
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + 2*m*n [rwork] < n + 5*n*n since m < 2*n here
                    nrwork = irvt
                    call stdlib_clacrm( m, n, u, ldu, rwork( iru ), n, a, lda,rwork( nrwork ) )
                              
                    call stdlib_clacpy( 'F', m, n, a, lda, u, ldu )
                 else
                    ! path 5a (m >> n, jobz='a')
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'U', n, n, a, lda, vt, ldvt )
                    call stdlib_cungbr( 'P', n, n, n, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! copy a to u, generate q
                    ! cworkspace: need   2*n [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'L', m, n, a, lda, u, ldu )
                    call stdlib_cungbr( 'Q', m, m, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply realmatrix rwork(irvt,KIND=sp) by p**h in vt,
                    ! storing the result in a, copying to vt
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + 2*n*n [rwork]
                    call stdlib_clarcm( n, n, rwork( irvt ), n, vt, ldvt, a, lda,rwork( nrwork ) )
                              
                    call stdlib_clacpy( 'F', n, n, a, lda, vt, ldvt )
                    ! multiply q in u by realmatrix rwork(iru,KIND=sp), storing the
                    ! result in a, copying to u
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + 2*m*n [rwork] < n + 5*n*n since m < 2*n here
                    nrwork = irvt
                    call stdlib_clacrm( m, n, u, ldu, rwork( iru ), n, a, lda,rwork( nrwork ) )
                              
                    call stdlib_clacpy( 'F', m, n, a, lda, u, ldu )
                 end if
              else
                 ! m < mnthr2
                 ! path 6 (m >= n, but not much larger)
                 ! reduce to bidiagonal form without qr decomposition
                 ! use stdlib_cunmbr to compute singular vectors
                 ie = 1_ilp
                 nrwork = ie + n
                 itauq = 1_ilp
                 itaup = itauq + n
                 nwork = itaup + n
                 ! bidiagonalize a
                 ! cworkspace: need   2*n [tauq, taup] + m        [work]
                 ! cworkspace: prefer 2*n [tauq, taup] + (m+n)*nb [work]
                 ! rworkspace: need   n [e]
                 call stdlib_cgebrd( m, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 6n (m >= n, jobz='n')
                    ! compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + bdspac
                    call stdlib_sbdsdc( 'U', 'N', n, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    iu = nwork
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    if( lwork >= m*n + 3_ilp*n ) then
                       ! work( iu ) is m by n
                       ldwrku = m
                    else
                       ! work( iu ) is ldwrku by n
                       ldwrku = ( lwork - 3_ilp*n ) / n
                    end if
                    nwork = iu + ldwrku*n
                    ! path 6o (m >= n, jobz='o')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + n*n [u] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*n [u] + n*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_clacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                    if( lwork >= m*n + 3_ilp*n ) then
                       ! path 6o-fast
                       ! copy realmatrix rwork(iru,KIND=sp) to complex matrix work(iu)
                       ! overwrite work(iu) by left singular vectors of a, copying
                       ! to a
                       ! cworkspace: need   2*n [tauq, taup] + m*n [u] + n    [work]
                       ! cworkspace: prefer 2*n [tauq, taup] + m*n [u] + n*nb [work]
                       ! rworkspace: need   n [e] + n*n [ru]
                       call stdlib_claset( 'F', m, n, czero, czero, work( iu ),ldwrku )
                       call stdlib_clacp2( 'F', n, n, rwork( iru ), n, work( iu ),ldwrku )
                       call stdlib_cunmbr( 'Q', 'L', 'N', m, n, n, a, lda,work( itauq ), work( iu &
                                 ), ldwrku,work( nwork ), lwork-nwork+1, ierr )
                       call stdlib_clacpy( 'F', m, n, work( iu ), ldwrku, a, lda )
                    else
                       ! path 6o-slow
                       ! generate q in a
                       ! cworkspace: need   2*n [tauq, taup] + n*n [u] + n    [work]
                       ! cworkspace: prefer 2*n [tauq, taup] + n*n [u] + n*nb [work]
                       ! rworkspace: need   0
                       call stdlib_cungbr( 'Q', m, n, n, a, lda, work( itauq ),work( nwork ), &
                                 lwork-nwork+1, ierr )
                       ! multiply q in a by realmatrix rwork(iru,KIND=sp), storing the
                       ! result in work(iu), copying to a
                       ! cworkspace: need   2*n [tauq, taup] + n*n [u]
                       ! cworkspace: prefer 2*n [tauq, taup] + m*n [u]
                       ! rworkspace: need   n [e] + n*n [ru] + 2*n*n [rwork]
                       ! rworkspace: prefer n [e] + n*n [ru] + 2*m*n [rwork] < n + 5*n*n since m < 2*n here
                       nrwork = irvt
                       do i = 1, m, ldwrku
                          chunk = min( m-i+1, ldwrku )
                          call stdlib_clacrm( chunk, n, a( i, 1_ilp ), lda,rwork( iru ), n, work( iu )&
                                    , ldwrku,rwork( nrwork ) )
                          call stdlib_clacpy( 'F', chunk, n, work( iu ), ldwrku,a( i, 1_ilp ), lda )
                                    
                       end do
                    end if
                 else if( wntqs ) then
                    ! path 6s (m >= n, jobz='s')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_claset( 'F', m, n, czero, czero, u, ldu )
                    call stdlib_clacp2( 'F', n, n, rwork( iru ), n, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', m, n, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_clacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                 else
                    ! path 6a (m >= n, jobz='a')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_sbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! set the right corner of u to identity matrix
                    call stdlib_claset( 'F', m, m, czero, czero, u, ldu )
                    if( m>n ) then
                       call stdlib_claset( 'F', m-n, m-n, czero, cone,u( n+1, n+1 ), ldu )
                    end if
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + m*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_clacp2( 'F', n, n, rwork( iru ), n, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_clacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                 end if
              end if
           else
              ! a has more columns than rows. if a has sufficiently more
              ! columns than rows, first reduce using the lq decomposition (if
              ! sufficient workspace available)
              if( n>=mnthr1 ) then
                 if( wntqn ) then
                    ! path 1t (n >> m, jobz='n')
                    ! no singular vectors to be computed
                    itau = 1_ilp
                    nwork = itau + m
                    ! compute a=l*q
                    ! cworkspace: need   m [tau] + m    [work]
                    ! cworkspace: prefer m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! zero out above l
                    if (m>1_ilp) call stdlib_claset( 'U', m-1, m-1, czero, czero, a( 1_ilp, 2_ilp ),lda )
                    ie = 1_ilp
                    itauq = 1_ilp
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in a
                    ! cworkspace: need   2*m [tauq, taup] + m      [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + 2*m*nb [work]
                    ! rworkspace: need   m [e]
                    call stdlib_cgebrd( m, m, a, lda, s, rwork( ie ), work( itauq ),work( itaup ),&
                               work( nwork ), lwork-nwork+1,ierr )
                    nrwork = ie + m
                    ! perform bidiagonal svd, compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + bdspac
                    call stdlib_sbdsdc( 'U', 'N', m, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 2t (n >> m, jobz='o')
                    ! m right singular vectors to be overwritten on a and
                    ! m left singular vectors to be computed in u
                    ivt = 1_ilp
                    ldwkvt = m
                    ! work(ivt) is m by m
                    il = ivt + ldwkvt*m
                    if( lwork >= m*n + m*m + 3_ilp*m ) then
                       ! work(il) m by n
                       ldwrkl = m
                       chunk = n
                    else
                       ! work(il) is m by chunk
                       ldwrkl = m
                       chunk = ( lwork - m*m - 3_ilp*m ) / m
                    end if
                    itau = il + ldwrkl*chunk
                    nwork = itau + m
                    ! compute a=l*q
                    ! cworkspace: need   m*m [vt] + m*m [l] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! copy l to work(il), zeroing about above it
                    call stdlib_clacpy( 'L', m, m, a, lda, work( il ), ldwrkl )
                    call stdlib_claset( 'U', m-1, m-1, czero, czero,work( il+ldwrkl ), ldwrkl )
                              
                    ! generate q in a
                    ! cworkspace: need   m*m [vt] + m*m [l] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cunglq( m, n, m, a, lda, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in work(il)
                    ! cworkspace: need   m*m [vt] + m*m [l] + 2*m [tauq, taup] + m      [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + 2*m [tauq, taup] + 2*m*nb [work]
                    ! rworkspace: need   m [e]
                    call stdlib_cgebrd( m, m, work( il ), ldwrkl, s, rwork( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [ru] + m*m [rvt] + bdspac
                    iru = ie + m
                    irvt = iru + m*m
                    nrwork = irvt + m*m
                    call stdlib_sbdsdc( 'U', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix work(iu)
                    ! overwrite work(iu) by the left singular vectors of l
                    ! cworkspace: need   m*m [vt] + m*m [l] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', m, m, m, work( il ), ldwrkl,work( itauq ), &
                              u, ldu, work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix work(ivt)
                    ! overwrite work(ivt) by the right singular vectors of l
                    ! cworkspace: need   m*m [vt] + m*m [l] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', m, m, rwork( irvt ), m, work( ivt ),ldwkvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', m, m, m, work( il ), ldwrkl,work( itaup ), &
                              work( ivt ), ldwkvt,work( nwork ), lwork-nwork+1, ierr )
                    ! multiply right singular vectors of l in work(il) by q
                    ! in a, storing result in work(il) and copying to a
                    ! cworkspace: need   m*m [vt] + m*m [l]
                    ! cworkspace: prefer m*m [vt] + m*n [l]
                    ! rworkspace: need   0
                    do i = 1, n, chunk
                       blk = min( n-i+1, chunk )
                       call stdlib_cgemm( 'N', 'N', m, blk, m, cone, work( ivt ), m,a( 1_ilp, i ), &
                                 lda, czero, work( il ),ldwrkl )
                       call stdlib_clacpy( 'F', m, blk, work( il ), ldwrkl,a( 1_ilp, i ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 3t (n >> m, jobz='s')
                    ! m right singular vectors to be computed in vt and
                    ! m left singular vectors to be computed in u
                    il = 1_ilp
                    ! work(il) is m by m
                    ldwrkl = m
                    itau = il + ldwrkl*m
                    nwork = itau + m
                    ! compute a=l*q
                    ! cworkspace: need   m*m [l] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [l] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! copy l to work(il), zeroing out above it
                    call stdlib_clacpy( 'L', m, m, a, lda, work( il ), ldwrkl )
                    call stdlib_claset( 'U', m-1, m-1, czero, czero,work( il+ldwrkl ), ldwrkl )
                              
                    ! generate q in a
                    ! cworkspace: need   m*m [l] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [l] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cunglq( m, n, m, a, lda, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in work(il)
                    ! cworkspace: need   m*m [l] + 2*m [tauq, taup] + m      [work]
                    ! cworkspace: prefer m*m [l] + 2*m [tauq, taup] + 2*m*nb [work]
                    ! rworkspace: need   m [e]
                    call stdlib_cgebrd( m, m, work( il ), ldwrkl, s, rwork( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [ru] + m*m [rvt] + bdspac
                    iru = ie + m
                    irvt = iru + m*m
                    nrwork = irvt + m*m
                    call stdlib_sbdsdc( 'U', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix u
                    ! overwrite u by left singular vectors of l
                    ! cworkspace: need   m*m [l] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [l] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', m, m, m, work( il ), ldwrkl,work( itauq ), &
                              u, ldu, work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by left singular vectors of l
                    ! cworkspace: need   m*m [l] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [l] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', m, m, rwork( irvt ), m, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', m, m, m, work( il ), ldwrkl,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork-nwork+1, ierr )
                    ! copy vt to work(il), multiply right singular vectors of l
                    ! in work(il) by q in a, storing result in vt
                    ! cworkspace: need   m*m [l]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'F', m, m, vt, ldvt, work( il ), ldwrkl )
                    call stdlib_cgemm( 'N', 'N', m, n, m, cone, work( il ), ldwrkl,a, lda, czero, &
                              vt, ldvt )
                 else if( wntqa ) then
                    ! path 4t (n >> m, jobz='a')
                    ! n right singular vectors to be computed in vt and
                    ! m left singular vectors to be computed in u
                    ivt = 1_ilp
                    ! work(ivt) is m by m
                    ldwkvt = m
                    itau = ivt + ldwkvt*m
                    nwork = itau + m
                    ! compute a=l*q, copying result to vt
                    ! cworkspace: need   m*m [vt] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    call stdlib_clacpy( 'U', m, n, a, lda, vt, ldvt )
                    ! generate q in vt
                    ! cworkspace: need   m*m [vt] + m [tau] + n    [work]
                    ! cworkspace: prefer m*m [vt] + m [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cunglq( n, n, m, vt, ldvt, work( itau ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! produce l in a, zeroing out above it
                    if (m>1_ilp) call stdlib_claset( 'U', m-1, m-1, czero, czero, a( 1_ilp, 2_ilp ),lda )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in a
                    ! cworkspace: need   m*m [vt] + 2*m [tauq, taup] + m      [work]
                    ! cworkspace: prefer m*m [vt] + 2*m [tauq, taup] + 2*m*nb [work]
                    ! rworkspace: need   m [e]
                    call stdlib_cgebrd( m, m, a, lda, s, rwork( ie ), work( itauq ),work( itaup ),&
                               work( nwork ), lwork-nwork+1,ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [ru] + m*m [rvt] + bdspac
                    iru = ie + m
                    irvt = iru + m*m
                    nrwork = irvt + m*m
                    call stdlib_sbdsdc( 'U', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix u
                    ! overwrite u by left singular vectors of l
                    ! cworkspace: need   m*m [vt] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [vt] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', m, m, m, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix work(ivt)
                    ! overwrite work(ivt) by right singular vectors of l
                    ! cworkspace: need   m*m [vt] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [vt] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacp2( 'F', m, m, rwork( irvt ), m, work( ivt ),ldwkvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', m, m, m, a, lda,work( itaup ), work( ivt ),&
                               ldwkvt,work( nwork ), lwork-nwork+1, ierr )
                    ! multiply right singular vectors of l in work(ivt) by
                    ! q in vt, storing result in a
                    ! cworkspace: need   m*m [vt]
                    ! rworkspace: need   0
                    call stdlib_cgemm( 'N', 'N', m, n, m, cone, work( ivt ), ldwkvt,vt, ldvt, &
                              czero, a, lda )
                    ! copy right singular vectors of a from a to vt
                    call stdlib_clacpy( 'F', m, n, a, lda, vt, ldvt )
                 end if
              else if( n>=mnthr2 ) then
                 ! mnthr2 <= n < mnthr1
                 ! path 5t (n >> m, but not as much as mnthr1)
                 ! reduce to bidiagonal form without qr decomposition, use
                 ! stdlib_cungbr and matrix multiplication to compute singular vectors
                 ie = 1_ilp
                 nrwork = ie + m
                 itauq = 1_ilp
                 itaup = itauq + m
                 nwork = itaup + m
                 ! bidiagonalize a
                 ! cworkspace: need   2*m [tauq, taup] + n        [work]
                 ! cworkspace: prefer 2*m [tauq, taup] + (m+n)*nb [work]
                 ! rworkspace: need   m [e]
                 call stdlib_cgebrd( m, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 5tn (n >> m, jobz='n')
                    ! compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + bdspac
                    call stdlib_sbdsdc( 'L', 'N', m, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    ivt = nwork
                    ! path 5to (n >> m, jobz='o')
                    ! copy a to u, generate q
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'L', m, m, a, lda, u, ldu )
                    call stdlib_cungbr( 'Q', m, m, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! generate p**h in a
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_cungbr( 'P', m, n, m, a, lda, work( itaup ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ldwkvt = m
                    if( lwork >= m*n + 3_ilp*m ) then
                       ! work( ivt ) is m by n
                       nwork = ivt + ldwkvt*n
                       chunk = n
                    else
                       ! work( ivt ) is m by chunk
                       chunk = ( lwork - 3_ilp*m ) / m
                       nwork = ivt + ldwkvt*chunk
                    end if
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    call stdlib_sbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply q in u by realmatrix rwork(irvt,KIND=sp)
                    ! storing the result in work(ivt), copying to u
                    ! cworkspace: need   2*m [tauq, taup] + m*m [vt]
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + 2*m*m [rwork]
                    call stdlib_clacrm( m, m, u, ldu, rwork( iru ), m, work( ivt ),ldwkvt, rwork( &
                              nrwork ) )
                    call stdlib_clacpy( 'F', m, m, work( ivt ), ldwkvt, u, ldu )
                    ! multiply rwork(irvt) by p**h in a, storing the
                    ! result in work(ivt), copying to a
                    ! cworkspace: need   2*m [tauq, taup] + m*m [vt]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*n [vt]
                    ! rworkspace: need   m [e] + m*m [rvt] + 2*m*m [rwork]
                    ! rworkspace: prefer m [e] + m*m [rvt] + 2*m*n [rwork] < m + 5*m*m since n < 2*m here
                    nrwork = iru
                    do i = 1, n, chunk
                       blk = min( n-i+1, chunk )
                       call stdlib_clarcm( m, blk, rwork( irvt ), m, a( 1_ilp, i ), lda,work( ivt ), &
                                 ldwkvt, rwork( nrwork ) )
                       call stdlib_clacpy( 'F', m, blk, work( ivt ), ldwkvt,a( 1_ilp, i ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 5ts (n >> m, jobz='s')
                    ! copy a to u, generate q
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'L', m, m, a, lda, u, ldu )
                    call stdlib_cungbr( 'Q', m, m, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'U', m, n, a, lda, vt, ldvt )
                    call stdlib_cungbr( 'P', m, n, m, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_sbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply q in u by realmatrix rwork(iru,KIND=sp), storing the
                    ! result in a, copying to u
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + 2*m*m [rwork]
                    call stdlib_clacrm( m, m, u, ldu, rwork( iru ), m, a, lda,rwork( nrwork ) )
                              
                    call stdlib_clacpy( 'F', m, m, a, lda, u, ldu )
                    ! multiply realmatrix rwork(irvt,KIND=sp) by p**h in vt,
                    ! storing the result in a, copying to vt
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + 2*m*n [rwork] < m + 5*m*m since n < 2*m here
                    nrwork = iru
                    call stdlib_clarcm( m, n, rwork( irvt ), m, vt, ldvt, a, lda,rwork( nrwork ) )
                              
                    call stdlib_clacpy( 'F', m, n, a, lda, vt, ldvt )
                 else
                    ! path 5ta (n >> m, jobz='a')
                    ! copy a to u, generate q
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'L', m, m, a, lda, u, ldu )
                    call stdlib_cungbr( 'Q', m, m, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*m [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_clacpy( 'U', m, n, a, lda, vt, ldvt )
                    call stdlib_cungbr( 'P', n, n, m, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_sbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply q in u by realmatrix rwork(iru,KIND=sp), storing the
                    ! result in a, copying to u
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + 2*m*m [rwork]
                    call stdlib_clacrm( m, m, u, ldu, rwork( iru ), m, a, lda,rwork( nrwork ) )
                              
                    call stdlib_clacpy( 'F', m, m, a, lda, u, ldu )
                    ! multiply realmatrix rwork(irvt,KIND=sp) by p**h in vt,
                    ! storing the result in a, copying to vt
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + 2*m*n [rwork] < m + 5*m*m since n < 2*m here
                    nrwork = iru
                    call stdlib_clarcm( m, n, rwork( irvt ), m, vt, ldvt, a, lda,rwork( nrwork ) )
                              
                    call stdlib_clacpy( 'F', m, n, a, lda, vt, ldvt )
                 end if
              else
                 ! n < mnthr2
                 ! path 6t (n > m, but not much larger)
                 ! reduce to bidiagonal form without lq decomposition
                 ! use stdlib_cunmbr to compute singular vectors
                 ie = 1_ilp
                 nrwork = ie + m
                 itauq = 1_ilp
                 itaup = itauq + m
                 nwork = itaup + m
                 ! bidiagonalize a
                 ! cworkspace: need   2*m [tauq, taup] + n        [work]
                 ! cworkspace: prefer 2*m [tauq, taup] + (m+n)*nb [work]
                 ! rworkspace: need   m [e]
                 call stdlib_cgebrd( m, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 6tn (n > m, jobz='n')
                    ! compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + bdspac
                    call stdlib_sbdsdc( 'L', 'N', m, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 6to (n > m, jobz='o')
                    ldwkvt = m
                    ivt = nwork
                    if( lwork >= m*n + 3_ilp*m ) then
                       ! work( ivt ) is m by n
                       call stdlib_claset( 'F', m, n, czero, czero, work( ivt ),ldwkvt )
                       nwork = ivt + ldwkvt*n
                    else
                       ! work( ivt ) is m by chunk
                       chunk = ( lwork - 3_ilp*m ) / m
                       nwork = ivt + ldwkvt*chunk
                    end if
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_sbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + m*m [vt] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*m [vt] + m*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru]
                    call stdlib_clacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    if( lwork >= m*n + 3_ilp*m ) then
                       ! path 6to-fast
                       ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix work(ivt)
                       ! overwrite work(ivt) by right singular vectors of a,
                       ! copying to a
                       ! cworkspace: need   2*m [tauq, taup] + m*n [vt] + m    [work]
                       ! cworkspace: prefer 2*m [tauq, taup] + m*n [vt] + m*nb [work]
                       ! rworkspace: need   m [e] + m*m [rvt]
                       call stdlib_clacp2( 'F', m, m, rwork( irvt ), m, work( ivt ),ldwkvt )
                                 
                       call stdlib_cunmbr( 'P', 'R', 'C', m, n, m, a, lda,work( itaup ), work( &
                                 ivt ), ldwkvt,work( nwork ), lwork-nwork+1, ierr )
                       call stdlib_clacpy( 'F', m, n, work( ivt ), ldwkvt, a, lda )
                    else
                       ! path 6to-slow
                       ! generate p**h in a
                       ! cworkspace: need   2*m [tauq, taup] + m*m [vt] + m    [work]
                       ! cworkspace: prefer 2*m [tauq, taup] + m*m [vt] + m*nb [work]
                       ! rworkspace: need   0
                       call stdlib_cungbr( 'P', m, n, m, a, lda, work( itaup ),work( nwork ), &
                                 lwork-nwork+1, ierr )
                       ! multiply q in a by realmatrix rwork(iru,KIND=sp), storing the
                       ! result in work(iu), copying to a
                       ! cworkspace: need   2*m [tauq, taup] + m*m [vt]
                       ! cworkspace: prefer 2*m [tauq, taup] + m*n [vt]
                       ! rworkspace: need   m [e] + m*m [rvt] + 2*m*m [rwork]
                       ! rworkspace: prefer m [e] + m*m [rvt] + 2*m*n [rwork] < m + 5*m*m since n < 2*m here
                       nrwork = iru
                       do i = 1, n, chunk
                          blk = min( n-i+1, chunk )
                          call stdlib_clarcm( m, blk, rwork( irvt ), m, a( 1_ilp, i ),lda, work( ivt )&
                                    , ldwkvt,rwork( nrwork ) )
                          call stdlib_clacpy( 'F', m, blk, work( ivt ), ldwkvt,a( 1_ilp, i ), lda )
                                    
                       end do
                    end if
                 else if( wntqs ) then
                    ! path 6ts (n > m, jobz='s')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_sbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru]
                    call stdlib_clacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt]
                    call stdlib_claset( 'F', m, n, czero, czero, vt, ldvt )
                    call stdlib_clacp2( 'F', m, m, rwork( irvt ), m, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', m, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                 else
                    ! path 6ta (n > m, jobz='a')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_sbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=sp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru]
                    call stdlib_clacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_cunmbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! set all of vt to identity matrix
                    call stdlib_claset( 'F', n, n, czero, cone, vt, ldvt )
                    ! copy realmatrix rwork(irvt,KIND=sp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + n*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt]
                    call stdlib_clacp2( 'F', m, m, rwork( irvt ), m, vt, ldvt )
                    call stdlib_cunmbr( 'P', 'R', 'C', n, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                 end if
              end if
           end if
           ! undo scaling if necessary
           if( iscl==1_ilp ) then
              if( anrm>bignum )call stdlib_slascl( 'G', 0_ilp, 0_ilp, bignum, anrm, minmn, 1_ilp, s, minmn,&
                        ierr )
              if( info/=0_ilp .and. anrm>bignum )call stdlib_slascl( 'G', 0_ilp, 0_ilp, bignum, anrm, minmn-1,&
                         1_ilp,rwork( ie ), minmn, ierr )
              if( anrm<smlnum )call stdlib_slascl( 'G', 0_ilp, 0_ilp, smlnum, anrm, minmn, 1_ilp, s, minmn,&
                        ierr )
              if( info/=0_ilp .and. anrm<smlnum )call stdlib_slascl( 'G', 0_ilp, 0_ilp, smlnum, anrm, minmn-1,&
                         1_ilp,rwork( ie ), minmn, ierr )
           end if
           ! return optimal workspace in work(1)
           work( 1_ilp ) = stdlib_sroundup_lwork( maxwrk )
           return
     end subroutine stdlib_cgesdd

     module subroutine stdlib_zgesdd( jobz, m, n, a, lda, s, u, ldu, vt, ldvt,work, lwork, rwork, iwork, &
     !! ZGESDD computes the singular value decomposition (SVD) of a complex
     !! M-by-N matrix A, optionally computing the left and/or right singular
     !! vectors, by using divide-and-conquer method. The SVD is written
     !! A = U * SIGMA * conjugate-transpose(V)
     !! where SIGMA is an M-by-N matrix which is zero except for its
     !! min(m,n) diagonal elements, U is an M-by-M unitary matrix, and
     !! V is an N-by-N unitary matrix.  The diagonal elements of SIGMA
     !! are the singular values of A; they are real and non-negative, and
     !! are returned in descending order.  The first min(m,n) columns of
     !! U and V are the left and right singular vectors of A.
     !! Note that the routine returns VT = V**H, not V.
     !! The divide and conquer algorithm makes very mild assumptions about
     !! floating point arithmetic. It will work on machines with a guard
     !! digit in add/subtract, or on those binary machines without guard
     !! digits which subtract like the Cray X-MP, Cray Y-MP, Cray C-90, or
     !! Cray-2. It could conceivably fail on hexadecimal or decimal machines
     !! without guard digits, but we know of none.
               info )
        ! -- lapack driver routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_dp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           character, intent(in) :: jobz
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldu, ldvt, lwork, m, n
           ! Array Arguments 
           integer(ilp), intent(out) :: iwork(*)
           real(dp), intent(out) :: rwork(*), s(*)
           complex(dp), intent(inout) :: a(lda,*)
           complex(dp), intent(out) :: u(ldu,*), vt(ldvt,*), work(*)
        ! =====================================================================
           
           
           ! Local Scalars 
           logical(lk) :: lquery, wntqa, wntqas, wntqn, wntqo, wntqs
           integer(ilp) :: blk, chunk, i, ie, ierr, il, ir, iru, irvt, iscl, itau, itaup, itauq, &
           iu, ivt, ldwkvt, ldwrkl, ldwrkr, ldwrku, maxwrk, minmn, minwrk, mnthr1, mnthr2, nrwork,&
                      nwork, wrkbl
           integer(ilp) :: lwork_zgebrd_mn, lwork_zgebrd_mm, lwork_zgebrd_nn, lwork_zgelqf_mn, &
           lwork_zgeqrf_mn, lwork_zungbr_p_mn, lwork_zungbr_p_nn, lwork_zungbr_q_mn, &
           lwork_zungbr_q_mm, lwork_zunglq_mn, lwork_zunglq_nn, lwork_zungqr_mm, lwork_zungqr_mn, &
           lwork_zunmbr_prc_mm, lwork_zunmbr_qln_mm, lwork_zunmbr_prc_mn, lwork_zunmbr_qln_mn, &
                     lwork_zunmbr_prc_nn, lwork_zunmbr_qln_nn
           real(dp) :: anrm, bignum, eps, smlnum
           ! Local Arrays 
           integer(ilp) :: idum(1_ilp)
           real(dp) :: dum(1_ilp)
           complex(dp) :: cdum(1_ilp)
           ! Intrinsic Functions 
           ! Executable Statements 
           ! test the input arguments
           info   = 0_ilp
           minmn  = min( m, n )
           mnthr1 = int( minmn*17.0_dp / 9.0_dp,KIND=ilp)
           mnthr2 = int( minmn*5.0_dp / 3.0_dp,KIND=ilp)
           wntqa  = stdlib_lsame( jobz, 'A' )
           wntqs  = stdlib_lsame( jobz, 'S' )
           wntqas = wntqa .or. wntqs
           wntqo  = stdlib_lsame( jobz, 'O' )
           wntqn  = stdlib_lsame( jobz, 'N' )
           lquery = ( lwork==-1_ilp )
           minwrk = 1_ilp
           maxwrk = 1_ilp
           if( .not.( wntqa .or. wntqs .or. wntqo .or. wntqn ) ) then
              info = -1_ilp
           else if( m<0_ilp ) then
              info = -2_ilp
           else if( n<0_ilp ) then
              info = -3_ilp
           else if( lda<max( 1_ilp, m ) ) then
              info = -5_ilp
           else if( ldu<1_ilp .or. ( wntqas .and. ldu<m ) .or.( wntqo .and. m<n .and. ldu<m ) ) &
                     then
              info = -8_ilp
           else if( ldvt<1_ilp .or. ( wntqa .and. ldvt<n ) .or.( wntqs .and. ldvt<minmn ) .or.( wntqo &
                     .and. m>=n .and. ldvt<n ) ) then
              info = -10_ilp
           end if
           ! compute workspace
             ! note: comments in the code beginning "workspace:" describe the
             ! minimal amount of workspace allocated at that point in the code,
             ! as well as the preferred amount for good performance.
             ! cworkspace refers to complex workspace, and rworkspace to
             ! real workspace. nb refers to the optimal block size for the
             ! immediately following subroutine, as returned by stdlib_ilaenv.)
           if( info==0_ilp ) then
              minwrk = 1_ilp
              maxwrk = 1_ilp
              if( m>=n .and. minmn>0_ilp ) then
                 ! there is no complex work space needed for bidiagonal svd
                 ! the realwork space needed for bidiagonal svd (stdlib_dbdsdc,KIND=dp) is
                 ! bdspac = 3*n*n + 4*n for singular values and vectors;
                 ! bdspac = 4*n         for singular values only;
                 ! not including e, ru, and rvt matrices.
                 ! compute space preferred for each routine
                 call stdlib_zgebrd( m, n, cdum(1_ilp), m, dum(1_ilp), dum(1_ilp), cdum(1_ilp),cdum(1_ilp), cdum(1_ilp), -&
                           1_ilp, ierr )
                 lwork_zgebrd_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zgebrd( n, n, cdum(1_ilp), n, dum(1_ilp), dum(1_ilp), cdum(1_ilp),cdum(1_ilp), cdum(1_ilp), -&
                           1_ilp, ierr )
                 lwork_zgebrd_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zgeqrf( m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp), -1_ilp, ierr )
                 lwork_zgeqrf_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zungbr( 'P', n, n, n, cdum(1_ilp), n, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zungbr_p_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zungbr( 'Q', m, m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zungbr_q_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zungbr( 'Q', m, n, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zungbr_q_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zungqr( m, m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zungqr_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zungqr( m, n, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zungqr_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunmbr( 'P', 'R', 'C', n, n, n, cdum(1_ilp), n, cdum(1_ilp),cdum(1_ilp), n, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_zunmbr_prc_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunmbr( 'Q', 'L', 'N', m, m, n, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_zunmbr_qln_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunmbr( 'Q', 'L', 'N', m, n, n, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_zunmbr_qln_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunmbr( 'Q', 'L', 'N', n, n, n, cdum(1_ilp), n, cdum(1_ilp),cdum(1_ilp), n, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_zunmbr_qln_nn = int( cdum(1_ilp),KIND=ilp)
                 if( m>=mnthr1 ) then
                    if( wntqn ) then
                       ! path 1 (m >> n, jobz='n')
                       maxwrk = n + lwork_zgeqrf_mn
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zgebrd_nn )
                       minwrk = 3_ilp*n
                    else if( wntqo ) then
                       ! path 2 (m >> n, jobz='o')
                       wrkbl = n + lwork_zgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_zungqr_mn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zgebrd_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zunmbr_qln_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zunmbr_prc_nn )
                       maxwrk = m*n + n*n + wrkbl
                       minwrk = 2_ilp*n*n + 3_ilp*n
                    else if( wntqs ) then
                       ! path 3 (m >> n, jobz='s')
                       wrkbl = n + lwork_zgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_zungqr_mn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zgebrd_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zunmbr_qln_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zunmbr_prc_nn )
                       maxwrk = n*n + wrkbl
                       minwrk = n*n + 3_ilp*n
                    else if( wntqa ) then
                       ! path 4 (m >> n, jobz='a')
                       wrkbl = n + lwork_zgeqrf_mn
                       wrkbl = max( wrkbl,   n + lwork_zungqr_mm )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zgebrd_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zunmbr_qln_nn )
                       wrkbl = max( wrkbl, 2_ilp*n + lwork_zunmbr_prc_nn )
                       maxwrk = n*n + wrkbl
                       minwrk = n*n + max( 3_ilp*n, n + m )
                    end if
                 else if( m>=mnthr2 ) then
                    ! path 5 (m >> n, but not as much as mnthr1)
                    maxwrk = 2_ilp*n + lwork_zgebrd_mn
                    minwrk = 2_ilp*n + m
                    if( wntqo ) then
                       ! path 5o (m >> n, jobz='o')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zungbr_p_nn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zungbr_q_mn )
                       maxwrk = maxwrk + m*n
                       minwrk = minwrk + n*n
                    else if( wntqs ) then
                       ! path 5s (m >> n, jobz='s')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zungbr_p_nn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zungbr_q_mn )
                    else if( wntqa ) then
                       ! path 5a (m >> n, jobz='a')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zungbr_p_nn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zungbr_q_mm )
                    end if
                 else
                    ! path 6 (m >= n, but not much larger)
                    maxwrk = 2_ilp*n + lwork_zgebrd_mn
                    minwrk = 2_ilp*n + m
                    if( wntqo ) then
                       ! path 6o (m >= n, jobz='o')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zunmbr_prc_nn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zunmbr_qln_mn )
                       maxwrk = maxwrk + m*n
                       minwrk = minwrk + n*n
                    else if( wntqs ) then
                       ! path 6s (m >= n, jobz='s')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zunmbr_qln_mn )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zunmbr_prc_nn )
                    else if( wntqa ) then
                       ! path 6a (m >= n, jobz='a')
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zunmbr_qln_mm )
                       maxwrk = max( maxwrk, 2_ilp*n + lwork_zunmbr_prc_nn )
                    end if
                 end if
              else if( minmn>0_ilp ) then
                 ! there is no complex work space needed for bidiagonal svd
                 ! the realwork space needed for bidiagonal svd (stdlib_dbdsdc,KIND=dp) is
                 ! bdspac = 3*m*m + 4*m for singular values and vectors;
                 ! bdspac = 4*m         for singular values only;
                 ! not including e, ru, and rvt matrices.
                 ! compute space preferred for each routine
                 call stdlib_zgebrd( m, n, cdum(1_ilp), m, dum(1_ilp), dum(1_ilp), cdum(1_ilp),cdum(1_ilp), cdum(1_ilp), -&
                           1_ilp, ierr )
                 lwork_zgebrd_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zgebrd( m, m, cdum(1_ilp), m, dum(1_ilp), dum(1_ilp), cdum(1_ilp),cdum(1_ilp), cdum(1_ilp), -&
                           1_ilp, ierr )
                 lwork_zgebrd_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zgelqf( m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp), -1_ilp, ierr )
                 lwork_zgelqf_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zungbr( 'P', m, n, m, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zungbr_p_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zungbr( 'P', n, n, m, cdum(1_ilp), n, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zungbr_p_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zungbr( 'Q', m, m, n, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zungbr_q_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunglq( m, n, m, cdum(1_ilp), m, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zunglq_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunglq( n, n, m, cdum(1_ilp), n, cdum(1_ilp), cdum(1_ilp),-1_ilp, ierr )
                 lwork_zunglq_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunmbr( 'P', 'R', 'C', m, m, m, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_zunmbr_prc_mm = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunmbr( 'P', 'R', 'C', m, n, m, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_zunmbr_prc_mn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunmbr( 'P', 'R', 'C', n, n, m, cdum(1_ilp), n, cdum(1_ilp),cdum(1_ilp), n, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_zunmbr_prc_nn = int( cdum(1_ilp),KIND=ilp)
                 call stdlib_zunmbr( 'Q', 'L', 'N', m, m, m, cdum(1_ilp), m, cdum(1_ilp),cdum(1_ilp), m, cdum(&
                           1_ilp), -1_ilp, ierr )
                 lwork_zunmbr_qln_mm = int( cdum(1_ilp),KIND=ilp)
                 if( n>=mnthr1 ) then
                    if( wntqn ) then
                       ! path 1t (n >> m, jobz='n')
                       maxwrk = m + lwork_zgelqf_mn
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zgebrd_mm )
                       minwrk = 3_ilp*m
                    else if( wntqo ) then
                       ! path 2t (n >> m, jobz='o')
                       wrkbl = m + lwork_zgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_zunglq_mn )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zgebrd_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zunmbr_qln_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zunmbr_prc_mm )
                       maxwrk = m*n + m*m + wrkbl
                       minwrk = 2_ilp*m*m + 3_ilp*m
                    else if( wntqs ) then
                       ! path 3t (n >> m, jobz='s')
                       wrkbl = m + lwork_zgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_zunglq_mn )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zgebrd_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zunmbr_qln_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zunmbr_prc_mm )
                       maxwrk = m*m + wrkbl
                       minwrk = m*m + 3_ilp*m
                    else if( wntqa ) then
                       ! path 4t (n >> m, jobz='a')
                       wrkbl = m + lwork_zgelqf_mn
                       wrkbl = max( wrkbl,   m + lwork_zunglq_nn )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zgebrd_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zunmbr_qln_mm )
                       wrkbl = max( wrkbl, 2_ilp*m + lwork_zunmbr_prc_mm )
                       maxwrk = m*m + wrkbl
                       minwrk = m*m + max( 3_ilp*m, m + n )
                    end if
                 else if( n>=mnthr2 ) then
                    ! path 5t (n >> m, but not as much as mnthr1)
                    maxwrk = 2_ilp*m + lwork_zgebrd_mn
                    minwrk = 2_ilp*m + n
                    if( wntqo ) then
                       ! path 5to (n >> m, jobz='o')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zungbr_q_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zungbr_p_mn )
                       maxwrk = maxwrk + m*n
                       minwrk = minwrk + m*m
                    else if( wntqs ) then
                       ! path 5ts (n >> m, jobz='s')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zungbr_q_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zungbr_p_mn )
                    else if( wntqa ) then
                       ! path 5ta (n >> m, jobz='a')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zungbr_q_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zungbr_p_nn )
                    end if
                 else
                    ! path 6t (n > m, but not much larger)
                    maxwrk = 2_ilp*m + lwork_zgebrd_mn
                    minwrk = 2_ilp*m + n
                    if( wntqo ) then
                       ! path 6to (n > m, jobz='o')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zunmbr_qln_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zunmbr_prc_mn )
                       maxwrk = maxwrk + m*n
                       minwrk = minwrk + m*m
                    else if( wntqs ) then
                       ! path 6ts (n > m, jobz='s')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zunmbr_qln_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zunmbr_prc_mn )
                    else if( wntqa ) then
                       ! path 6ta (n > m, jobz='a')
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zunmbr_qln_mm )
                       maxwrk = max( maxwrk, 2_ilp*m + lwork_zunmbr_prc_nn )
                    end if
                 end if
              end if
              maxwrk = max( maxwrk, minwrk )
           end if
           if( info==0_ilp ) then
              work( 1_ilp ) = stdlib_droundup_lwork( maxwrk )
              if( lwork<minwrk .and. .not. lquery ) then
                 info = -12_ilp
              end if
           end if
           if( info/=0_ilp ) then
              call stdlib_xerbla( 'ZGESDD', -info )
              return
           else if( lquery ) then
              return
           end if
           ! quick return if possible
           if( m==0_ilp .or. n==0_ilp ) then
              return
           end if
           ! get machine constants
           eps = stdlib_dlamch( 'P' )
           smlnum = sqrt( stdlib_dlamch( 'S' ) ) / eps
           bignum = one / smlnum
           ! scale a if max element outside range [smlnum,bignum]
           anrm = stdlib_zlange( 'M', m, n, a, lda, dum )
           if( stdlib_disnan( anrm ) ) then
               info = -4_ilp
               return
           end if
           iscl = 0_ilp
           if( anrm>zero .and. anrm<smlnum ) then
              iscl = 1_ilp
              call stdlib_zlascl( 'G', 0_ilp, 0_ilp, anrm, smlnum, m, n, a, lda, ierr )
           else if( anrm>bignum ) then
              iscl = 1_ilp
              call stdlib_zlascl( 'G', 0_ilp, 0_ilp, anrm, bignum, m, n, a, lda, ierr )
           end if
           if( m>=n ) then
              ! a has at least as many rows as columns. if a has sufficiently
              ! more rows than columns, first reduce using the qr
              ! decomposition (if sufficient workspace available)
              if( m>=mnthr1 ) then
                 if( wntqn ) then
                    ! path 1 (m >> n, jobz='n')
                    ! no singular vectors to be computed
                    itau = 1_ilp
                    nwork = itau + n
                    ! compute a=q*r
                    ! cworkspace: need   n [tau] + n    [work]
                    ! cworkspace: prefer n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! zero out below r
                    if (n>1_ilp) call stdlib_zlaset( 'L', n-1, n-1, czero, czero, a( 2_ilp, 1_ilp ),lda )
                    ie = 1_ilp
                    itauq = 1_ilp
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in a
                    ! cworkspace: need   2*n [tauq, taup] + n      [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + 2*n*nb [work]
                    ! rworkspace: need   n [e]
                    call stdlib_zgebrd( n, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ),&
                               work( nwork ), lwork-nwork+1,ierr )
                    nrwork = ie + n
                    ! perform bidiagonal svd, compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + bdspac
                    call stdlib_dbdsdc( 'U', 'N', n, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 2 (m >> n, jobz='o')
                    ! n left singular vectors to be overwritten on a and
                    ! n right singular vectors to be computed in vt
                    iu = 1_ilp
                    ! work(iu) is n by n
                    ldwrku = n
                    ir = iu + ldwrku*n
                    if( lwork >= m*n + n*n + 3_ilp*n ) then
                       ! work(ir) is m by n
                       ldwrkr = m
                    else
                       ldwrkr = ( lwork - n*n - 3_ilp*n ) / n
                    end if
                    itau = ir + ldwrkr*n
                    nwork = itau + n
                    ! compute a=q*r
                    ! cworkspace: need   n*n [u] + n*n [r] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! copy r to work( ir ), zeroing out below it
                    call stdlib_zlacpy( 'U', n, n, a, lda, work( ir ), ldwrkr )
                    call stdlib_zlaset( 'L', n-1, n-1, czero, czero, work( ir+1 ),ldwrkr )
                    ! generate q in a
                    ! cworkspace: need   n*n [u] + n*n [r] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zungqr( m, n, n, a, lda, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in work(ir)
                    ! cworkspace: need   n*n [u] + n*n [r] + 2*n [tauq, taup] + n      [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + 2*n [tauq, taup] + 2*n*nb [work]
                    ! rworkspace: need   n [e]
                    call stdlib_zgebrd( n, n, work( ir ), ldwrkr, s, rwork( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of r in work(iru) and computing right singular vectors
                    ! of r in work(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = ie + n
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix work(iu)
                    ! overwrite work(iu) by the left singular vectors of r
                    ! cworkspace: need   n*n [u] + n*n [r] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', n, n, rwork( iru ), n, work( iu ),ldwrku )
                    call stdlib_zunmbr( 'Q', 'L', 'N', n, n, n, work( ir ), ldwrkr,work( itauq ), &
                              work( iu ), ldwrku,work( nwork ), lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by the right singular vectors of r
                    ! cworkspace: need   n*n [u] + n*n [r] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [u] + n*n [r] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', n, n, n, work( ir ), ldwrkr,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork-nwork+1, ierr )
                    ! multiply q in a by left singular vectors of r in
                    ! work(iu), storing result in work(ir) and copying to a
                    ! cworkspace: need   n*n [u] + n*n [r]
                    ! cworkspace: prefer n*n [u] + m*n [r]
                    ! rworkspace: need   0
                    do i = 1, m, ldwrkr
                       chunk = min( m-i+1, ldwrkr )
                       call stdlib_zgemm( 'N', 'N', chunk, n, n, cone, a( i, 1_ilp ),lda, work( iu ), &
                                 ldwrku, czero,work( ir ), ldwrkr )
                       call stdlib_zlacpy( 'F', chunk, n, work( ir ), ldwrkr,a( i, 1_ilp ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 3 (m >> n, jobz='s')
                    ! n left singular vectors to be computed in u and
                    ! n right singular vectors to be computed in vt
                    ir = 1_ilp
                    ! work(ir) is n by n
                    ldwrkr = n
                    itau = ir + ldwrkr*n
                    nwork = itau + n
                    ! compute a=q*r
                    ! cworkspace: need   n*n [r] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [r] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! copy r to work(ir), zeroing out below it
                    call stdlib_zlacpy( 'U', n, n, a, lda, work( ir ), ldwrkr )
                    call stdlib_zlaset( 'L', n-1, n-1, czero, czero, work( ir+1 ),ldwrkr )
                    ! generate q in a
                    ! cworkspace: need   n*n [r] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [r] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zungqr( m, n, n, a, lda, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in work(ir)
                    ! cworkspace: need   n*n [r] + 2*n [tauq, taup] + n      [work]
                    ! cworkspace: prefer n*n [r] + 2*n [tauq, taup] + 2*n*nb [work]
                    ! rworkspace: need   n [e]
                    call stdlib_zgebrd( n, n, work( ir ), ldwrkr, s, rwork( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = ie + n
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix u
                    ! overwrite u by left singular vectors of r
                    ! cworkspace: need   n*n [r] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [r] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', n, n, rwork( iru ), n, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', n, n, n, work( ir ), ldwrkr,work( itauq ), &
                              u, ldu, work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by right singular vectors of r
                    ! cworkspace: need   n*n [r] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [r] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', n, n, n, work( ir ), ldwrkr,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork-nwork+1, ierr )
                    ! multiply q in a by left singular vectors of r in
                    ! work(ir), storing result in u
                    ! cworkspace: need   n*n [r]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'F', n, n, u, ldu, work( ir ), ldwrkr )
                    call stdlib_zgemm( 'N', 'N', m, n, n, cone, a, lda, work( ir ),ldwrkr, czero, &
                              u, ldu )
                 else if( wntqa ) then
                    ! path 4 (m >> n, jobz='a')
                    ! m left singular vectors to be computed in u and
                    ! n right singular vectors to be computed in vt
                    iu = 1_ilp
                    ! work(iu) is n by n
                    ldwrku = n
                    itau = iu + ldwrku*n
                    nwork = itau + n
                    ! compute a=q*r, copying result to u
                    ! cworkspace: need   n*n [u] + n [tau] + n    [work]
                    ! cworkspace: prefer n*n [u] + n [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zgeqrf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    call stdlib_zlacpy( 'L', m, n, a, lda, u, ldu )
                    ! generate q in u
                    ! cworkspace: need   n*n [u] + n [tau] + m    [work]
                    ! cworkspace: prefer n*n [u] + n [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zungqr( m, m, n, u, ldu, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ! produce r in a, zeroing out below it
                    if (n>1_ilp) call stdlib_zlaset( 'L', n-1, n-1, czero, czero, a( 2_ilp, 1_ilp ),lda )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + n
                    nwork = itaup + n
                    ! bidiagonalize r in a
                    ! cworkspace: need   n*n [u] + 2*n [tauq, taup] + n      [work]
                    ! cworkspace: prefer n*n [u] + 2*n [tauq, taup] + 2*n*nb [work]
                    ! rworkspace: need   n [e]
                    call stdlib_zgebrd( n, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ),&
                               work( nwork ), lwork-nwork+1,ierr )
                    iru = ie + n
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix work(iu)
                    ! overwrite work(iu) by left singular vectors of r
                    ! cworkspace: need   n*n [u] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [u] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', n, n, rwork( iru ), n, work( iu ),ldwrku )
                    call stdlib_zunmbr( 'Q', 'L', 'N', n, n, n, a, lda,work( itauq ), work( iu ), &
                              ldwrku,work( nwork ), lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by right singular vectors of r
                    ! cworkspace: need   n*n [u] + 2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer n*n [u] + 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! multiply q in u by left singular vectors of r in
                    ! work(iu), storing result in a
                    ! cworkspace: need   n*n [u]
                    ! rworkspace: need   0
                    call stdlib_zgemm( 'N', 'N', m, n, n, cone, u, ldu, work( iu ),ldwrku, czero, &
                              a, lda )
                    ! copy left singular vectors of a from a to u
                    call stdlib_zlacpy( 'F', m, n, a, lda, u, ldu )
                 end if
              else if( m>=mnthr2 ) then
                 ! mnthr2 <= m < mnthr1
                 ! path 5 (m >> n, but not as much as mnthr1)
                 ! reduce to bidiagonal form without qr decomposition, use
                 ! stdlib_zungbr and matrix multiplication to compute singular vectors
                 ie = 1_ilp
                 nrwork = ie + n
                 itauq = 1_ilp
                 itaup = itauq + n
                 nwork = itaup + n
                 ! bidiagonalize a
                 ! cworkspace: need   2*n [tauq, taup] + m        [work]
                 ! cworkspace: prefer 2*n [tauq, taup] + (m+n)*nb [work]
                 ! rworkspace: need   n [e]
                 call stdlib_zgebrd( m, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 5n (m >> n, jobz='n')
                    ! compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + bdspac
                    call stdlib_dbdsdc( 'U', 'N', n, s, rwork( ie ), dum, 1_ilp,dum,1_ilp,dum, idum, &
                              rwork( nrwork ), iwork, info )
                 else if( wntqo ) then
                    iu = nwork
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    ! path 5o (m >> n, jobz='o')
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'U', n, n, a, lda, vt, ldvt )
                    call stdlib_zungbr( 'P', n, n, n, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! generate q in a
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zungbr( 'Q', m, n, n, a, lda, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    if( lwork >= m*n + 3_ilp*n ) then
                       ! work( iu ) is m by n
                       ldwrku = m
                    else
                       ! work(iu) is ldwrku by n
                       ldwrku = ( lwork - 3_ilp*n ) / n
                    end if
                    nwork = iu + ldwrku*n
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply realmatrix rwork(irvt,KIND=dp) by p**h in vt,
                    ! storing the result in work(iu), copying to vt
                    ! cworkspace: need   2*n [tauq, taup] + n*n [u]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + 2*n*n [rwork]
                    call stdlib_zlarcm( n, n, rwork( irvt ), n, vt, ldvt,work( iu ), ldwrku, &
                              rwork( nrwork ) )
                    call stdlib_zlacpy( 'F', n, n, work( iu ), ldwrku, vt, ldvt )
                    ! multiply q in a by realmatrix rwork(iru,KIND=dp), storing the
                    ! result in work(iu), copying to a
                    ! cworkspace: need   2*n [tauq, taup] + n*n [u]
                    ! cworkspace: prefer 2*n [tauq, taup] + m*n [u]
                    ! rworkspace: need   n [e] + n*n [ru] + 2*n*n [rwork]
                    ! rworkspace: prefer n [e] + n*n [ru] + 2*m*n [rwork] < n + 5*n*n since m < 2*n here
                    nrwork = irvt
                    do i = 1, m, ldwrku
                       chunk = min( m-i+1, ldwrku )
                       call stdlib_zlacrm( chunk, n, a( i, 1_ilp ), lda, rwork( iru ),n, work( iu ), &
                                 ldwrku, rwork( nrwork ) )
                       call stdlib_zlacpy( 'F', chunk, n, work( iu ), ldwrku,a( i, 1_ilp ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 5s (m >> n, jobz='s')
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'U', n, n, a, lda, vt, ldvt )
                    call stdlib_zungbr( 'P', n, n, n, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! copy a to u, generate q
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'L', m, n, a, lda, u, ldu )
                    call stdlib_zungbr( 'Q', m, n, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply realmatrix rwork(irvt,KIND=dp) by p**h in vt,
                    ! storing the result in a, copying to vt
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + 2*n*n [rwork]
                    call stdlib_zlarcm( n, n, rwork( irvt ), n, vt, ldvt, a, lda,rwork( nrwork ) )
                              
                    call stdlib_zlacpy( 'F', n, n, a, lda, vt, ldvt )
                    ! multiply q in u by realmatrix rwork(iru,KIND=dp), storing the
                    ! result in a, copying to u
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + 2*m*n [rwork] < n + 5*n*n since m < 2*n here
                    nrwork = irvt
                    call stdlib_zlacrm( m, n, u, ldu, rwork( iru ), n, a, lda,rwork( nrwork ) )
                              
                    call stdlib_zlacpy( 'F', m, n, a, lda, u, ldu )
                 else
                    ! path 5a (m >> n, jobz='a')
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'U', n, n, a, lda, vt, ldvt )
                    call stdlib_zungbr( 'P', n, n, n, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! copy a to u, generate q
                    ! cworkspace: need   2*n [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'L', m, n, a, lda, u, ldu )
                    call stdlib_zungbr( 'Q', m, m, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply realmatrix rwork(irvt,KIND=dp) by p**h in vt,
                    ! storing the result in a, copying to vt
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + 2*n*n [rwork]
                    call stdlib_zlarcm( n, n, rwork( irvt ), n, vt, ldvt, a, lda,rwork( nrwork ) )
                              
                    call stdlib_zlacpy( 'F', n, n, a, lda, vt, ldvt )
                    ! multiply q in u by realmatrix rwork(iru,KIND=dp), storing the
                    ! result in a, copying to u
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + 2*m*n [rwork] < n + 5*n*n since m < 2*n here
                    nrwork = irvt
                    call stdlib_zlacrm( m, n, u, ldu, rwork( iru ), n, a, lda,rwork( nrwork ) )
                              
                    call stdlib_zlacpy( 'F', m, n, a, lda, u, ldu )
                 end if
              else
                 ! m < mnthr2
                 ! path 6 (m >= n, but not much larger)
                 ! reduce to bidiagonal form without qr decomposition
                 ! use stdlib_zunmbr to compute singular vectors
                 ie = 1_ilp
                 nrwork = ie + n
                 itauq = 1_ilp
                 itaup = itauq + n
                 nwork = itaup + n
                 ! bidiagonalize a
                 ! cworkspace: need   2*n [tauq, taup] + m        [work]
                 ! cworkspace: prefer 2*n [tauq, taup] + (m+n)*nb [work]
                 ! rworkspace: need   n [e]
                 call stdlib_zgebrd( m, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 6n (m >= n, jobz='n')
                    ! compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + bdspac
                    call stdlib_dbdsdc( 'U', 'N', n, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    iu = nwork
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    if( lwork >= m*n + 3_ilp*n ) then
                       ! work( iu ) is m by n
                       ldwrku = m
                    else
                       ! work( iu ) is ldwrku by n
                       ldwrku = ( lwork - 3_ilp*n ) / n
                    end if
                    nwork = iu + ldwrku*n
                    ! path 6o (m >= n, jobz='o')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + n*n [u] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*n [u] + n*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_zlacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                    if( lwork >= m*n + 3_ilp*n ) then
                       ! path 6o-fast
                       ! copy realmatrix rwork(iru,KIND=dp) to complex matrix work(iu)
                       ! overwrite work(iu) by left singular vectors of a, copying
                       ! to a
                       ! cworkspace: need   2*n [tauq, taup] + m*n [u] + n    [work]
                       ! cworkspace: prefer 2*n [tauq, taup] + m*n [u] + n*nb [work]
                       ! rworkspace: need   n [e] + n*n [ru]
                       call stdlib_zlaset( 'F', m, n, czero, czero, work( iu ),ldwrku )
                       call stdlib_zlacp2( 'F', n, n, rwork( iru ), n, work( iu ),ldwrku )
                       call stdlib_zunmbr( 'Q', 'L', 'N', m, n, n, a, lda,work( itauq ), work( iu &
                                 ), ldwrku,work( nwork ), lwork-nwork+1, ierr )
                       call stdlib_zlacpy( 'F', m, n, work( iu ), ldwrku, a, lda )
                    else
                       ! path 6o-slow
                       ! generate q in a
                       ! cworkspace: need   2*n [tauq, taup] + n*n [u] + n    [work]
                       ! cworkspace: prefer 2*n [tauq, taup] + n*n [u] + n*nb [work]
                       ! rworkspace: need   0
                       call stdlib_zungbr( 'Q', m, n, n, a, lda, work( itauq ),work( nwork ), &
                                 lwork-nwork+1, ierr )
                       ! multiply q in a by realmatrix rwork(iru,KIND=dp), storing the
                       ! result in work(iu), copying to a
                       ! cworkspace: need   2*n [tauq, taup] + n*n [u]
                       ! cworkspace: prefer 2*n [tauq, taup] + m*n [u]
                       ! rworkspace: need   n [e] + n*n [ru] + 2*n*n [rwork]
                       ! rworkspace: prefer n [e] + n*n [ru] + 2*m*n [rwork] < n + 5*n*n since m < 2*n here
                       nrwork = irvt
                       do i = 1, m, ldwrku
                          chunk = min( m-i+1, ldwrku )
                          call stdlib_zlacrm( chunk, n, a( i, 1_ilp ), lda,rwork( iru ), n, work( iu )&
                                    , ldwrku,rwork( nrwork ) )
                          call stdlib_zlacpy( 'F', chunk, n, work( iu ), ldwrku,a( i, 1_ilp ), lda )
                                    
                       end do
                    end if
                 else if( wntqs ) then
                    ! path 6s (m >= n, jobz='s')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_zlaset( 'F', m, n, czero, czero, u, ldu )
                    call stdlib_zlacp2( 'F', n, n, rwork( iru ), n, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', m, n, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_zlacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                 else
                    ! path 6a (m >= n, jobz='a')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt] + bdspac
                    iru = nrwork
                    irvt = iru + n*n
                    nrwork = irvt + n*n
                    call stdlib_dbdsdc( 'U', 'I', n, s, rwork( ie ), rwork( iru ),n, rwork( irvt )&
                              , n, dum, idum,rwork( nrwork ), iwork, info )
                    ! set the right corner of u to identity matrix
                    call stdlib_zlaset( 'F', m, m, czero, czero, u, ldu )
                    if( m>n ) then
                       call stdlib_zlaset( 'F', m-n, m-n, czero, cone,u( n+1, n+1 ), ldu )
                    end if
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + m*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_zlacp2( 'F', n, n, rwork( iru ), n, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*n [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*n [tauq, taup] + n*nb [work]
                    ! rworkspace: need   n [e] + n*n [ru] + n*n [rvt]
                    call stdlib_zlacp2( 'F', n, n, rwork( irvt ), n, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', n, n, n, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                 end if
              end if
           else
              ! a has more columns than rows. if a has sufficiently more
              ! columns than rows, first reduce using the lq decomposition (if
              ! sufficient workspace available)
              if( n>=mnthr1 ) then
                 if( wntqn ) then
                    ! path 1t (n >> m, jobz='n')
                    ! no singular vectors to be computed
                    itau = 1_ilp
                    nwork = itau + m
                    ! compute a=l*q
                    ! cworkspace: need   m [tau] + m    [work]
                    ! cworkspace: prefer m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! zero out above l
                    if (m>1_ilp) call stdlib_zlaset( 'U', m-1, m-1, czero, czero, a( 1_ilp, 2_ilp ),lda )
                    ie = 1_ilp
                    itauq = 1_ilp
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in a
                    ! cworkspace: need   2*m [tauq, taup] + m      [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + 2*m*nb [work]
                    ! rworkspace: need   m [e]
                    call stdlib_zgebrd( m, m, a, lda, s, rwork( ie ), work( itauq ),work( itaup ),&
                               work( nwork ), lwork-nwork+1,ierr )
                    nrwork = ie + m
                    ! perform bidiagonal svd, compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + bdspac
                    call stdlib_dbdsdc( 'U', 'N', m, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 2t (n >> m, jobz='o')
                    ! m right singular vectors to be overwritten on a and
                    ! m left singular vectors to be computed in u
                    ivt = 1_ilp
                    ldwkvt = m
                    ! work(ivt) is m by m
                    il = ivt + ldwkvt*m
                    if( lwork >= m*n + m*m + 3_ilp*m ) then
                       ! work(il) m by n
                       ldwrkl = m
                       chunk = n
                    else
                       ! work(il) is m by chunk
                       ldwrkl = m
                       chunk = ( lwork - m*m - 3_ilp*m ) / m
                    end if
                    itau = il + ldwrkl*chunk
                    nwork = itau + m
                    ! compute a=l*q
                    ! cworkspace: need   m*m [vt] + m*m [l] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! copy l to work(il), zeroing about above it
                    call stdlib_zlacpy( 'L', m, m, a, lda, work( il ), ldwrkl )
                    call stdlib_zlaset( 'U', m-1, m-1, czero, czero,work( il+ldwrkl ), ldwrkl )
                              
                    ! generate q in a
                    ! cworkspace: need   m*m [vt] + m*m [l] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zunglq( m, n, m, a, lda, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in work(il)
                    ! cworkspace: need   m*m [vt] + m*m [l] + 2*m [tauq, taup] + m      [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + 2*m [tauq, taup] + 2*m*nb [work]
                    ! rworkspace: need   m [e]
                    call stdlib_zgebrd( m, m, work( il ), ldwrkl, s, rwork( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [ru] + m*m [rvt] + bdspac
                    iru = ie + m
                    irvt = iru + m*m
                    nrwork = irvt + m*m
                    call stdlib_dbdsdc( 'U', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix work(iu)
                    ! overwrite work(iu) by the left singular vectors of l
                    ! cworkspace: need   m*m [vt] + m*m [l] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', m, m, m, work( il ), ldwrkl,work( itauq ), &
                              u, ldu, work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix work(ivt)
                    ! overwrite work(ivt) by the right singular vectors of l
                    ! cworkspace: need   m*m [vt] + m*m [l] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m*m [l] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', m, m, rwork( irvt ), m, work( ivt ),ldwkvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', m, m, m, work( il ), ldwrkl,work( itaup ), &
                              work( ivt ), ldwkvt,work( nwork ), lwork-nwork+1, ierr )
                    ! multiply right singular vectors of l in work(il) by q
                    ! in a, storing result in work(il) and copying to a
                    ! cworkspace: need   m*m [vt] + m*m [l]
                    ! cworkspace: prefer m*m [vt] + m*n [l]
                    ! rworkspace: need   0
                    do i = 1, n, chunk
                       blk = min( n-i+1, chunk )
                       call stdlib_zgemm( 'N', 'N', m, blk, m, cone, work( ivt ), m,a( 1_ilp, i ), &
                                 lda, czero, work( il ),ldwrkl )
                       call stdlib_zlacpy( 'F', m, blk, work( il ), ldwrkl,a( 1_ilp, i ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 3t (n >> m, jobz='s')
                    ! m right singular vectors to be computed in vt and
                    ! m left singular vectors to be computed in u
                    il = 1_ilp
                    ! work(il) is m by m
                    ldwrkl = m
                    itau = il + ldwrkl*m
                    nwork = itau + m
                    ! compute a=l*q
                    ! cworkspace: need   m*m [l] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [l] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    ! copy l to work(il), zeroing out above it
                    call stdlib_zlacpy( 'L', m, m, a, lda, work( il ), ldwrkl )
                    call stdlib_zlaset( 'U', m-1, m-1, czero, czero,work( il+ldwrkl ), ldwrkl )
                              
                    ! generate q in a
                    ! cworkspace: need   m*m [l] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [l] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zunglq( m, n, m, a, lda, work( itau ),work( nwork ), lwork-nwork+&
                              1_ilp, ierr )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in work(il)
                    ! cworkspace: need   m*m [l] + 2*m [tauq, taup] + m      [work]
                    ! cworkspace: prefer m*m [l] + 2*m [tauq, taup] + 2*m*nb [work]
                    ! rworkspace: need   m [e]
                    call stdlib_zgebrd( m, m, work( il ), ldwrkl, s, rwork( ie ),work( itauq ), &
                              work( itaup ), work( nwork ),lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [ru] + m*m [rvt] + bdspac
                    iru = ie + m
                    irvt = iru + m*m
                    nrwork = irvt + m*m
                    call stdlib_dbdsdc( 'U', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix u
                    ! overwrite u by left singular vectors of l
                    ! cworkspace: need   m*m [l] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [l] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', m, m, m, work( il ), ldwrkl,work( itauq ), &
                              u, ldu, work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by left singular vectors of l
                    ! cworkspace: need   m*m [l] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [l] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', m, m, rwork( irvt ), m, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', m, m, m, work( il ), ldwrkl,work( itaup ), &
                              vt, ldvt, work( nwork ),lwork-nwork+1, ierr )
                    ! copy vt to work(il), multiply right singular vectors of l
                    ! in work(il) by q in a, storing result in vt
                    ! cworkspace: need   m*m [l]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'F', m, m, vt, ldvt, work( il ), ldwrkl )
                    call stdlib_zgemm( 'N', 'N', m, n, m, cone, work( il ), ldwrkl,a, lda, czero, &
                              vt, ldvt )
                 else if( wntqa ) then
                    ! path 4t (n >> m, jobz='a')
                    ! n right singular vectors to be computed in vt and
                    ! m left singular vectors to be computed in u
                    ivt = 1_ilp
                    ! work(ivt) is m by m
                    ldwkvt = m
                    itau = ivt + ldwkvt*m
                    nwork = itau + m
                    ! compute a=l*q, copying result to vt
                    ! cworkspace: need   m*m [vt] + m [tau] + m    [work]
                    ! cworkspace: prefer m*m [vt] + m [tau] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zgelqf( m, n, a, lda, work( itau ), work( nwork ),lwork-nwork+1, &
                              ierr )
                    call stdlib_zlacpy( 'U', m, n, a, lda, vt, ldvt )
                    ! generate q in vt
                    ! cworkspace: need   m*m [vt] + m [tau] + n    [work]
                    ! cworkspace: prefer m*m [vt] + m [tau] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zunglq( n, n, m, vt, ldvt, work( itau ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! produce l in a, zeroing out above it
                    if (m>1_ilp) call stdlib_zlaset( 'U', m-1, m-1, czero, czero, a( 1_ilp, 2_ilp ),lda )
                    ie = 1_ilp
                    itauq = itau
                    itaup = itauq + m
                    nwork = itaup + m
                    ! bidiagonalize l in a
                    ! cworkspace: need   m*m [vt] + 2*m [tauq, taup] + m      [work]
                    ! cworkspace: prefer m*m [vt] + 2*m [tauq, taup] + 2*m*nb [work]
                    ! rworkspace: need   m [e]
                    call stdlib_zgebrd( m, m, a, lda, s, rwork( ie ), work( itauq ),work( itaup ),&
                               work( nwork ), lwork-nwork+1,ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [ru] + m*m [rvt] + bdspac
                    iru = ie + m
                    irvt = iru + m*m
                    nrwork = irvt + m*m
                    call stdlib_dbdsdc( 'U', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix u
                    ! overwrite u by left singular vectors of l
                    ! cworkspace: need   m*m [vt] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [vt] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', m, m, m, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix work(ivt)
                    ! overwrite work(ivt) by right singular vectors of l
                    ! cworkspace: need   m*m [vt] + 2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer m*m [vt] + 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacp2( 'F', m, m, rwork( irvt ), m, work( ivt ),ldwkvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', m, m, m, a, lda,work( itaup ), work( ivt ),&
                               ldwkvt,work( nwork ), lwork-nwork+1, ierr )
                    ! multiply right singular vectors of l in work(ivt) by
                    ! q in vt, storing result in a
                    ! cworkspace: need   m*m [vt]
                    ! rworkspace: need   0
                    call stdlib_zgemm( 'N', 'N', m, n, m, cone, work( ivt ), ldwkvt,vt, ldvt, &
                              czero, a, lda )
                    ! copy right singular vectors of a from a to vt
                    call stdlib_zlacpy( 'F', m, n, a, lda, vt, ldvt )
                 end if
              else if( n>=mnthr2 ) then
                 ! mnthr2 <= n < mnthr1
                 ! path 5t (n >> m, but not as much as mnthr1)
                 ! reduce to bidiagonal form without qr decomposition, use
                 ! stdlib_zungbr and matrix multiplication to compute singular vectors
                 ie = 1_ilp
                 nrwork = ie + m
                 itauq = 1_ilp
                 itaup = itauq + m
                 nwork = itaup + m
                 ! bidiagonalize a
                 ! cworkspace: need   2*m [tauq, taup] + n        [work]
                 ! cworkspace: prefer 2*m [tauq, taup] + (m+n)*nb [work]
                 ! rworkspace: need   m [e]
                 call stdlib_zgebrd( m, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 5tn (n >> m, jobz='n')
                    ! compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + bdspac
                    call stdlib_dbdsdc( 'L', 'N', m, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    ivt = nwork
                    ! path 5to (n >> m, jobz='o')
                    ! copy a to u, generate q
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'L', m, m, a, lda, u, ldu )
                    call stdlib_zungbr( 'Q', m, m, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! generate p**h in a
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zungbr( 'P', m, n, m, a, lda, work( itaup ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ldwkvt = m
                    if( lwork >= m*n + 3_ilp*m ) then
                       ! work( ivt ) is m by n
                       nwork = ivt + ldwkvt*n
                       chunk = n
                    else
                       ! work( ivt ) is m by chunk
                       chunk = ( lwork - 3_ilp*m ) / m
                       nwork = ivt + ldwkvt*chunk
                    end if
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    call stdlib_dbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply q in u by realmatrix rwork(irvt,KIND=dp)
                    ! storing the result in work(ivt), copying to u
                    ! cworkspace: need   2*m [tauq, taup] + m*m [vt]
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + 2*m*m [rwork]
                    call stdlib_zlacrm( m, m, u, ldu, rwork( iru ), m, work( ivt ),ldwkvt, rwork( &
                              nrwork ) )
                    call stdlib_zlacpy( 'F', m, m, work( ivt ), ldwkvt, u, ldu )
                    ! multiply rwork(irvt) by p**h in a, storing the
                    ! result in work(ivt), copying to a
                    ! cworkspace: need   2*m [tauq, taup] + m*m [vt]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*n [vt]
                    ! rworkspace: need   m [e] + m*m [rvt] + 2*m*m [rwork]
                    ! rworkspace: prefer m [e] + m*m [rvt] + 2*m*n [rwork] < m + 5*m*m since n < 2*m here
                    nrwork = iru
                    do i = 1, n, chunk
                       blk = min( n-i+1, chunk )
                       call stdlib_zlarcm( m, blk, rwork( irvt ), m, a( 1_ilp, i ), lda,work( ivt ), &
                                 ldwkvt, rwork( nrwork ) )
                       call stdlib_zlacpy( 'F', m, blk, work( ivt ), ldwkvt,a( 1_ilp, i ), lda )
                                 
                    end do
                 else if( wntqs ) then
                    ! path 5ts (n >> m, jobz='s')
                    ! copy a to u, generate q
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'L', m, m, a, lda, u, ldu )
                    call stdlib_zungbr( 'Q', m, m, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'U', m, n, a, lda, vt, ldvt )
                    call stdlib_zungbr( 'P', m, n, m, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_dbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply q in u by realmatrix rwork(iru,KIND=dp), storing the
                    ! result in a, copying to u
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + 2*m*m [rwork]
                    call stdlib_zlacrm( m, m, u, ldu, rwork( iru ), m, a, lda,rwork( nrwork ) )
                              
                    call stdlib_zlacpy( 'F', m, m, a, lda, u, ldu )
                    ! multiply realmatrix rwork(irvt,KIND=dp) by p**h in vt,
                    ! storing the result in a, copying to vt
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + 2*m*n [rwork] < m + 5*m*m since n < 2*m here
                    nrwork = iru
                    call stdlib_zlarcm( m, n, rwork( irvt ), m, vt, ldvt, a, lda,rwork( nrwork ) )
                              
                    call stdlib_zlacpy( 'F', m, n, a, lda, vt, ldvt )
                 else
                    ! path 5ta (n >> m, jobz='a')
                    ! copy a to u, generate q
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'L', m, m, a, lda, u, ldu )
                    call stdlib_zungbr( 'Q', m, m, n, u, ldu, work( itauq ),work( nwork ), lwork-&
                              nwork+1, ierr )
                    ! copy a to vt, generate p**h
                    ! cworkspace: need   2*m [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + n*nb [work]
                    ! rworkspace: need   0
                    call stdlib_zlacpy( 'U', m, n, a, lda, vt, ldvt )
                    call stdlib_zungbr( 'P', n, n, m, vt, ldvt, work( itaup ),work( nwork ), &
                              lwork-nwork+1, ierr )
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_dbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! multiply q in u by realmatrix rwork(iru,KIND=dp), storing the
                    ! result in a, copying to u
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + 2*m*m [rwork]
                    call stdlib_zlacrm( m, m, u, ldu, rwork( iru ), m, a, lda,rwork( nrwork ) )
                              
                    call stdlib_zlacpy( 'F', m, m, a, lda, u, ldu )
                    ! multiply realmatrix rwork(irvt,KIND=dp) by p**h in vt,
                    ! storing the result in a, copying to vt
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + 2*m*n [rwork] < m + 5*m*m since n < 2*m here
                    nrwork = iru
                    call stdlib_zlarcm( m, n, rwork( irvt ), m, vt, ldvt, a, lda,rwork( nrwork ) )
                              
                    call stdlib_zlacpy( 'F', m, n, a, lda, vt, ldvt )
                 end if
              else
                 ! n < mnthr2
                 ! path 6t (n > m, but not much larger)
                 ! reduce to bidiagonal form without lq decomposition
                 ! use stdlib_zunmbr to compute singular vectors
                 ie = 1_ilp
                 nrwork = ie + m
                 itauq = 1_ilp
                 itaup = itauq + m
                 nwork = itaup + m
                 ! bidiagonalize a
                 ! cworkspace: need   2*m [tauq, taup] + n        [work]
                 ! cworkspace: prefer 2*m [tauq, taup] + (m+n)*nb [work]
                 ! rworkspace: need   m [e]
                 call stdlib_zgebrd( m, n, a, lda, s, rwork( ie ), work( itauq ),work( itaup ), &
                           work( nwork ), lwork-nwork+1,ierr )
                 if( wntqn ) then
                    ! path 6tn (n > m, jobz='n')
                    ! compute singular values only
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + bdspac
                    call stdlib_dbdsdc( 'L', 'N', m, s, rwork( ie ), dum,1_ilp,dum,1_ilp,dum, idum, rwork(&
                               nrwork ), iwork, info )
                 else if( wntqo ) then
                    ! path 6to (n > m, jobz='o')
                    ldwkvt = m
                    ivt = nwork
                    if( lwork >= m*n + 3_ilp*m ) then
                       ! work( ivt ) is m by n
                       call stdlib_zlaset( 'F', m, n, czero, czero, work( ivt ),ldwkvt )
                       nwork = ivt + ldwkvt*n
                    else
                       ! work( ivt ) is m by chunk
                       chunk = ( lwork - 3_ilp*m ) / m
                       nwork = ivt + ldwkvt*chunk
                    end if
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_dbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + m*m [vt] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*m [vt] + m*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru]
                    call stdlib_zlacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    if( lwork >= m*n + 3_ilp*m ) then
                       ! path 6to-fast
                       ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix work(ivt)
                       ! overwrite work(ivt) by right singular vectors of a,
                       ! copying to a
                       ! cworkspace: need   2*m [tauq, taup] + m*n [vt] + m    [work]
                       ! cworkspace: prefer 2*m [tauq, taup] + m*n [vt] + m*nb [work]
                       ! rworkspace: need   m [e] + m*m [rvt]
                       call stdlib_zlacp2( 'F', m, m, rwork( irvt ), m, work( ivt ),ldwkvt )
                                 
                       call stdlib_zunmbr( 'P', 'R', 'C', m, n, m, a, lda,work( itaup ), work( &
                                 ivt ), ldwkvt,work( nwork ), lwork-nwork+1, ierr )
                       call stdlib_zlacpy( 'F', m, n, work( ivt ), ldwkvt, a, lda )
                    else
                       ! path 6to-slow
                       ! generate p**h in a
                       ! cworkspace: need   2*m [tauq, taup] + m*m [vt] + m    [work]
                       ! cworkspace: prefer 2*m [tauq, taup] + m*m [vt] + m*nb [work]
                       ! rworkspace: need   0
                       call stdlib_zungbr( 'P', m, n, m, a, lda, work( itaup ),work( nwork ), &
                                 lwork-nwork+1, ierr )
                       ! multiply q in a by realmatrix rwork(iru,KIND=dp), storing the
                       ! result in work(iu), copying to a
                       ! cworkspace: need   2*m [tauq, taup] + m*m [vt]
                       ! cworkspace: prefer 2*m [tauq, taup] + m*n [vt]
                       ! rworkspace: need   m [e] + m*m [rvt] + 2*m*m [rwork]
                       ! rworkspace: prefer m [e] + m*m [rvt] + 2*m*n [rwork] < m + 5*m*m since n < 2*m here
                       nrwork = iru
                       do i = 1, n, chunk
                          blk = min( n-i+1, chunk )
                          call stdlib_zlarcm( m, blk, rwork( irvt ), m, a( 1_ilp, i ),lda, work( ivt )&
                                    , ldwkvt,rwork( nrwork ) )
                          call stdlib_zlacpy( 'F', m, blk, work( ivt ), ldwkvt,a( 1_ilp, i ), lda )
                                    
                       end do
                    end if
                 else if( wntqs ) then
                    ! path 6ts (n > m, jobz='s')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_dbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru]
                    call stdlib_zlacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt]
                    call stdlib_zlaset( 'F', m, n, czero, czero, vt, ldvt )
                    call stdlib_zlacp2( 'F', m, m, rwork( irvt ), m, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', m, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                 else
                    ! path 6ta (n > m, jobz='a')
                    ! perform bidiagonal svd, computing left singular vectors
                    ! of bidiagonal matrix in rwork(iru) and computing right
                    ! singular vectors of bidiagonal matrix in rwork(irvt)
                    ! cworkspace: need   0
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru] + bdspac
                    irvt = nrwork
                    iru = irvt + m*m
                    nrwork = iru + m*m
                    call stdlib_dbdsdc( 'L', 'I', m, s, rwork( ie ), rwork( iru ),m, rwork( irvt )&
                              , m, dum, idum,rwork( nrwork ), iwork, info )
                    ! copy realmatrix rwork(iru,KIND=dp) to complex matrix u
                    ! overwrite u by left singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + m    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + m*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt] + m*m [ru]
                    call stdlib_zlacp2( 'F', m, m, rwork( iru ), m, u, ldu )
                    call stdlib_zunmbr( 'Q', 'L', 'N', m, m, n, a, lda,work( itauq ), u, ldu, &
                              work( nwork ),lwork-nwork+1, ierr )
                    ! set all of vt to identity matrix
                    call stdlib_zlaset( 'F', n, n, czero, cone, vt, ldvt )
                    ! copy realmatrix rwork(irvt,KIND=dp) to complex matrix vt
                    ! overwrite vt by right singular vectors of a
                    ! cworkspace: need   2*m [tauq, taup] + n    [work]
                    ! cworkspace: prefer 2*m [tauq, taup] + n*nb [work]
                    ! rworkspace: need   m [e] + m*m [rvt]
                    call stdlib_zlacp2( 'F', m, m, rwork( irvt ), m, vt, ldvt )
                    call stdlib_zunmbr( 'P', 'R', 'C', n, n, m, a, lda,work( itaup ), vt, ldvt, &
                              work( nwork ),lwork-nwork+1, ierr )
                 end if
              end if
           end if
           ! undo scaling if necessary
           if( iscl==1_ilp ) then
              if( anrm>bignum )call stdlib_dlascl( 'G', 0_ilp, 0_ilp, bignum, anrm, minmn, 1_ilp, s, minmn,&
                        ierr )
              if( info/=0_ilp .and. anrm>bignum )call stdlib_dlascl( 'G', 0_ilp, 0_ilp, bignum, anrm, minmn-1,&
                         1_ilp,rwork( ie ), minmn, ierr )
              if( anrm<smlnum )call stdlib_dlascl( 'G', 0_ilp, 0_ilp, smlnum, anrm, minmn, 1_ilp, s, minmn,&
                        ierr )
              if( info/=0_ilp .and. anrm<smlnum )call stdlib_dlascl( 'G', 0_ilp, 0_ilp, smlnum, anrm, minmn-1,&
                         1_ilp,rwork( ie ), minmn, ierr )
           end if
           ! return optimal workspace in work(1)
           work( 1_ilp ) = stdlib_droundup_lwork( maxwrk )
           return
     end subroutine stdlib_zgesdd




     pure module subroutine stdlib_sgejsv( joba, jobu, jobv, jobr, jobt, jobp,m, n, a, lda, sva, u, ldu, &
     !! SGEJSV computes the singular value decomposition (SVD) of a real M-by-N
     !! matrix [A], where M >= N. The SVD of [A] is written as
     !! [A] = [U] * [SIGMA] * [V]^t,
     !! where [SIGMA] is an N-by-N (M-by-N) matrix which is zero except for its N
     !! diagonal elements, [U] is an M-by-N (or M-by-M) orthonormal matrix, and
     !! [V] is an N-by-N orthogonal matrix. The diagonal elements of [SIGMA] are
     !! the singular values of [A]. The columns of [U] and [V] are the left and
     !! the right singular vectors of [A], respectively. The matrices [U] and [V]
     !! are computed and stored in the arrays U and V, respectively. The diagonal
     !! of [SIGMA] is computed and stored in the array SVA.
     !! SGEJSV can sometimes compute tiny singular values and their singular vectors much
     !! more accurately than other SVD routines, see below under Further Details.
               v, ldv,work, lwork, iwork, info )
        ! -- lapack computational routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_sp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldu, ldv, lwork, m, n
           ! Array Arguments 
           real(sp), intent(inout) :: a(lda,*)
           real(sp), intent(out) :: sva(n), u(ldu,*), v(ldv,*), work(lwork)
           integer(ilp), intent(out) :: iwork(*)
           character, intent(in) :: joba, jobp, jobr, jobt, jobu, jobv
        ! ===========================================================================
           
           ! Local Scalars 
           real(sp) :: aapp, aaqq, aatmax, aatmin, big, big1, cond_ok, condr1, condr2, entra, &
                     entrat, epsln, maxprj, scalem, sconda, sfmin, small, temp1, uscal1, uscal2, xsc
           integer(ilp) :: ierr, n1, nr, numrank, p, q, warning
           logical(lk) :: almort, defr, errest, goscal, jracc, kill, lsvec, l2aber, l2kill, &
                     l2pert, l2rank, l2tran, noscal, rowpiv, rsvec, transp
           ! Intrinsic Functions 
           ! test the input arguments
           lsvec  = stdlib_lsame( jobu, 'U' ) .or. stdlib_lsame( jobu, 'F' )
           jracc  = stdlib_lsame( jobv, 'J' )
           rsvec  = stdlib_lsame( jobv, 'V' ) .or. jracc
           rowpiv = stdlib_lsame( joba, 'F' ) .or. stdlib_lsame( joba, 'G' )
           l2rank = stdlib_lsame( joba, 'R' )
           l2aber = stdlib_lsame( joba, 'A' )
           errest = stdlib_lsame( joba, 'E' ) .or. stdlib_lsame( joba, 'G' )
           l2tran = stdlib_lsame( jobt, 'T' )
           l2kill = stdlib_lsame( jobr, 'R' )
           defr   = stdlib_lsame( jobr, 'N' )
           l2pert = stdlib_lsame( jobp, 'P' )
           if ( .not.(rowpiv .or. l2rank .or. l2aber .or.errest .or. stdlib_lsame( joba, 'C' ) )) &
                     then
              info = - 1_ilp
           else if ( .not.( lsvec  .or. stdlib_lsame( jobu, 'N' ) .or.stdlib_lsame( jobu, 'W' )) )&
                      then
              info = - 2_ilp
           else if ( .not.( rsvec .or. stdlib_lsame( jobv, 'N' ) .or.stdlib_lsame( jobv, 'W' )) &
                     .or. ( jracc .and. (.not.lsvec) ) ) then
              info = - 3_ilp
           else if ( .not. ( l2kill .or. defr ) )    then
              info = - 4_ilp
           else if ( .not. ( l2tran .or. stdlib_lsame( jobt, 'N' ) ) ) then
              info = - 5_ilp
           else if ( .not. ( l2pert .or. stdlib_lsame( jobp, 'N' ) ) ) then
              info = - 6_ilp
           else if ( m < 0_ilp ) then
              info = - 7_ilp
           else if ( ( n < 0_ilp ) .or. ( n > m ) ) then
              info = - 8_ilp
           else if ( lda < m ) then
              info = - 10_ilp
           else if ( lsvec .and. ( ldu < m ) ) then
              info = - 13_ilp
           else if ( rsvec .and. ( ldv < n ) ) then
              info = - 15_ilp
           else if ( (.not.(lsvec .or. rsvec .or. errest).and.(lwork < max(7_ilp,4_ilp*n+1,2_ilp*m+n))) .or.(&
           .not.(lsvec .or. rsvec) .and. errest .and.(lwork < max(7_ilp,4_ilp*n+n*n,2_ilp*m+n))) .or.(lsvec &
           .and. (.not.rsvec) .and. (lwork < max(7_ilp,2_ilp*m+n,4_ilp*n+1))).or.(rsvec .and. (.not.lsvec) &
           .and. (lwork < max(7_ilp,2_ilp*m+n,4_ilp*n+1))).or.(lsvec .and. rsvec .and. (.not.jracc) .and.(&
           lwork<max(2_ilp*m+n,6_ilp*n+2*n*n))).or. (lsvec .and. rsvec .and. jracc .and.lwork<max(2_ilp*m+n,&
                     4_ilp*n+n*n,2_ilp*n+n*n+6)))then
              info = - 17_ilp
           else
              ! #:)
              info = 0_ilp
           end if
           if ( info /= 0_ilp ) then
             ! #:(
              call stdlib_xerbla( 'SGEJSV', - info )
              return
           end if
           ! quick return for void matrix (y3k safe)
       ! #:)
           if ( ( m == 0_ilp ) .or. ( n == 0_ilp ) ) then
              iwork(1_ilp:3_ilp) = 0_ilp
              work(1_ilp:7_ilp) = 0_ilp
              return
           endif
           ! determine whether the matrix u should be m x n or m x m
           if ( lsvec ) then
              n1 = n
              if ( stdlib_lsame( jobu, 'F' ) ) n1 = m
           end if
           ! set numerical parameters
      ! !    note: make sure stdlib_slamch() does not fail on the target architecture.
           epsln = stdlib_slamch('EPSILON')
           sfmin = stdlib_slamch('SAFEMINIMUM')
           small = sfmin / epsln
           big   = stdlib_slamch('O')
           ! big   = one / sfmin
           ! initialize sva(1:n) = diag( ||a e_i||_2 )_1^n
      ! (!)  if necessary, scale sva() to protect the largest norm from
           ! overflow. it is possible that this scaling pushes the smallest
           ! column norm left from the underflow threshold (extreme case).
           scalem  = one / sqrt(real(m,KIND=sp)*real(n,KIND=sp))
           noscal  = .true.
           goscal  = .true.
           do p = 1, n
              aapp = zero
              aaqq = one
              call stdlib_slassq( m, a(1_ilp,p), 1_ilp, aapp, aaqq )
              if ( aapp > big ) then
                 info = - 9_ilp
                 call stdlib_xerbla( 'SGEJSV', -info )
                 return
              end if
              aaqq = sqrt(aaqq)
              if ( ( aapp < (big / aaqq) ) .and. noscal  ) then
                 sva(p)  = aapp * aaqq
              else
                 noscal  = .false.
                 sva(p)  = aapp * ( aaqq * scalem )
                 if ( goscal ) then
                    goscal = .false.
                    call stdlib_sscal( p-1, scalem, sva, 1_ilp )
                 end if
              end if
           end do
           if ( noscal ) scalem = one
           aapp = zero
           aaqq = big
           do p = 1, n
              aapp = max( aapp, sva(p) )
              if ( sva(p) /= zero ) aaqq = min( aaqq, sva(p) )
           end do
           ! quick return for zero m x n matrix
       ! #:)
           if ( aapp == zero ) then
              if ( lsvec ) call stdlib_slaset( 'G', m, n1, zero, one, u, ldu )
              if ( rsvec ) call stdlib_slaset( 'G', n, n,  zero, one, v, ldv )
              work(1_ilp) = one
              work(2_ilp) = one
              if ( errest ) work(3_ilp) = one
              if ( lsvec .and. rsvec ) then
                 work(4_ilp) = one
                 work(5_ilp) = one
              end if
              if ( l2tran ) then
                 work(6_ilp) = zero
                 work(7_ilp) = zero
              end if
              iwork(1_ilp) = 0_ilp
              iwork(2_ilp) = 0_ilp
              iwork(3_ilp) = 0_ilp
              return
           end if
           ! issue warning if denormalized column norms detected. override the
           ! high relative accuracy request. issue licence to kill columns
           ! (set them to zero) whose norm is less than sigma_max / big (roughly).
       ! #:(
           warning = 0_ilp
           if ( aaqq <= sfmin ) then
              l2rank = .true.
              l2kill = .true.
              warning = 1_ilp
           end if
           ! quick return for one-column matrix
       ! #:)
           if ( n == 1_ilp ) then
              if ( lsvec ) then
                 call stdlib_slascl( 'G',0_ilp,0_ilp,sva(1_ilp),scalem, m,1_ilp,a(1_ilp,1_ilp),lda,ierr )
                 call stdlib_slacpy( 'A', m, 1_ilp, a, lda, u, ldu )
                 ! computing all m left singular vectors of the m x 1 matrix
                 if ( n1 /= n  ) then
                    call stdlib_sgeqrf( m, n, u,ldu, work, work(n+1),lwork-n,ierr )
                    call stdlib_sorgqr( m,n1,1_ilp, u,ldu,work,work(n+1),lwork-n,ierr )
                    call stdlib_scopy( m, a(1_ilp,1_ilp), 1_ilp, u(1_ilp,1_ilp), 1_ilp )
                 end if
              end if
              if ( rsvec ) then
                  v(1_ilp,1_ilp) = one
              end if
              if ( sva(1_ilp) < (big*scalem) ) then
                 sva(1_ilp)  = sva(1_ilp) / scalem
                 scalem  = one
              end if
              work(1_ilp) = one / scalem
              work(2_ilp) = one
              if ( sva(1_ilp) /= zero ) then
                 iwork(1_ilp) = 1_ilp
                 if ( ( sva(1_ilp) / scalem) >= sfmin ) then
                    iwork(2_ilp) = 1_ilp
                 else
                    iwork(2_ilp) = 0_ilp
                 end if
              else
                 iwork(1_ilp) = 0_ilp
                 iwork(2_ilp) = 0_ilp
              end if
              iwork(3_ilp) = 0_ilp
              if ( errest ) work(3_ilp) = one
              if ( lsvec .and. rsvec ) then
                 work(4_ilp) = one
                 work(5_ilp) = one
              end if
              if ( l2tran ) then
                 work(6_ilp) = zero
                 work(7_ilp) = zero
              end if
              return
           end if
           transp = .false.
           l2tran = l2tran .and. ( m == n )
           aatmax = -one
           aatmin =  big
           if ( rowpiv .or. l2tran ) then
           ! compute the row norms, needed to determine row pivoting sequence
           ! (in the case of heavily row weighted a, row pivoting is strongly
           ! advised) and to collect information needed to compare the
           ! structures of a * a^t and a^t * a (in the case l2tran==.true.).
              if ( l2tran ) then
                 do p = 1, m
                    xsc   = zero
                    temp1 = one
                    call stdlib_slassq( n, a(p,1_ilp), lda, xsc, temp1 )
                    ! stdlib_slassq gets both the ell_2 and the ell_infinity norm
                    ! in one pass through the vector
                    work(m+n+p)  = xsc * scalem
                    work(n+p)    = xsc * (scalem*sqrt(temp1))
                    aatmax = max( aatmax, work(n+p) )
                    if (work(n+p) /= zero) aatmin = min(aatmin,work(n+p))
                 end do
              else
                 do p = 1, m
                    work(m+n+p) = scalem*abs( a(p,stdlib_isamax(n,a(p,1_ilp),lda)) )
                    aatmax = max( aatmax, work(m+n+p) )
                    aatmin = min( aatmin, work(m+n+p) )
                 end do
              end if
           end if
           ! for square matrix a try to determine whether a^t  would be  better
           ! input for the preconditioned jacobi svd, with faster convergence.
           ! the decision is based on an o(n) function of the vector of column
           ! and row norms of a, based on the shannon entropy. this should give
           ! the right choice in most cases when the difference actually matters.
           ! it may fail and pick the slower converging side.
           entra  = zero
           entrat = zero
           if ( l2tran ) then
              xsc   = zero
              temp1 = one
              call stdlib_slassq( n, sva, 1_ilp, xsc, temp1 )
              temp1 = one / temp1
              entra = zero
              do p = 1, n
                 big1  = ( ( sva(p) / xsc )**2_ilp ) * temp1
                 if ( big1 /= zero ) entra = entra + big1 * log(big1)
              end do
              entra = - entra / log(real(n,KIND=sp))
              ! now, sva().^2/trace(a^t * a) is a point in the probability simplex.
              ! it is derived from the diagonal of  a^t * a.  do the same with the
              ! diagonal of a * a^t, compute the entropy of the corresponding
              ! probability distribution. note that a * a^t and a^t * a have the
              ! same trace.
              entrat = zero
              do p = n+1, n+m
                 big1 = ( ( work(p) / xsc )**2_ilp ) * temp1
                 if ( big1 /= zero ) entrat = entrat + big1 * log(big1)
              end do
              entrat = - entrat / log(real(m,KIND=sp))
              ! analyze the entropies and decide a or a^t. smaller entropy
              ! usually means better input for the algorithm.
              transp = ( entrat < entra )
              ! if a^t is better than a, transpose a.
              if ( transp ) then
                 ! in an optimal implementation, this trivial transpose
                 ! should be replaced with faster transpose.
                 do p = 1, n - 1
                    do q = p + 1, n
                        temp1 = a(q,p)
                       a(q,p) = a(p,q)
                       a(p,q) = temp1
                    end do
                 end do
                 do p = 1, n
                    work(m+n+p) = sva(p)
                    sva(p)      = work(n+p)
                 end do
                 temp1  = aapp
                 aapp   = aatmax
                 aatmax = temp1
                 temp1  = aaqq
                 aaqq   = aatmin
                 aatmin = temp1
                 kill   = lsvec
                 lsvec  = rsvec
                 rsvec  = kill
                 if ( lsvec ) n1 = n
                 rowpiv = .true.
              end if
           end if
           ! end if l2tran
           ! scale the matrix so that its maximal singular value remains less
           ! than sqrt(big) -- the matrix is scaled so that its maximal column
           ! has euclidean norm equal to sqrt(big/n). the only reason to keep
           ! sqrt(big) instead of big is the fact that stdlib_sgejsv uses lapack and
           ! blas routines that, in some implementations, are not capable of
           ! working in the full interval [sfmin,big] and that they may provoke
           ! overflows in the intermediate results. if the singular values spread
           ! from sfmin to big, then stdlib_sgesvj will compute them. so, in that case,
           ! one should use stdlib_sgesvj instead of stdlib_sgejsv.
           big1   = sqrt( big )
           temp1  = sqrt( big / real(n,KIND=sp) )
           call stdlib_slascl( 'G', 0_ilp, 0_ilp, aapp, temp1, n, 1_ilp, sva, n, ierr )
           if ( aaqq > (aapp * sfmin) ) then
               aaqq = ( aaqq / aapp ) * temp1
           else
               aaqq = ( aaqq * temp1 ) / aapp
           end if
           temp1 = temp1 * scalem
           call stdlib_slascl( 'G', 0_ilp, 0_ilp, aapp, temp1, m, n, a, lda, ierr )
           ! to undo scaling at the end of this procedure, multiply the
           ! computed singular values with uscal2 / uscal1.
           uscal1 = temp1
           uscal2 = aapp
           if ( l2kill ) then
              ! l2kill enforces computation of nonzero singular values in
              ! the restricted range of condition number of the initial a,
              ! sigma_max(a) / sigma_min(a) approx. sqrt(big)/sqrt(sfmin).
              xsc = sqrt( sfmin )
           else
              xsc = small
              ! now, if the condition number of a is too big,
              ! sigma_max(a) / sigma_min(a) > sqrt(big/n) * epsln / sfmin,
              ! as a precaution measure, the full svd is computed using stdlib_sgesvj
              ! with accumulated jacobi rotations. this provides numerically
              ! more robust computation, at the cost of slightly increased run
              ! time. depending on the concrete implementation of blas and lapack
              ! (i.e. how they behave in presence of extreme ill-conditioning) the
              ! implementor may decide to remove this switch.
              if ( ( aaqq<sqrt(sfmin) ) .and. lsvec .and. rsvec ) then
                 jracc = .true.
              end if
           end if
           if ( aaqq < xsc ) then
              do p = 1, n
                 if ( sva(p) < xsc ) then
                    call stdlib_slaset( 'A', m, 1_ilp, zero, zero, a(1_ilp,p), lda )
                    sva(p) = zero
                 end if
              end do
           end if
           ! preconditioning using qr factorization with pivoting
           if ( rowpiv ) then
              ! optional row permutation (bjoerck row pivoting):
              ! a result by cox and higham shows that the bjoerck's
              ! row pivoting combined with standard column pivoting
              ! has similar effect as powell-reid complete pivoting.
              ! the ell-infinity norms of a are made nonincreasing.
              do p = 1, m - 1
                 q = stdlib_isamax( m-p+1, work(m+n+p), 1_ilp ) + p - 1_ilp
                 iwork(2_ilp*n+p) = q
                 if ( p /= q ) then
                    temp1       = work(m+n+p)
                    work(m+n+p) = work(m+n+q)
                    work(m+n+q) = temp1
                 end if
              end do
              call stdlib_slaswp( n, a, lda, 1_ilp, m-1, iwork(2_ilp*n+1), 1_ilp )
           end if
           ! end of the preparation phase (scaling, optional sorting and
           ! transposing, optional flushing of small columns).
           ! preconditioning
           ! if the full svd is needed, the right singular vectors are computed
           ! from a matrix equation, and for that we need theoretical analysis
           ! of the businger-golub pivoting. so we use stdlib_sgeqp3 as the first rr qrf.
           ! in all other cases the first rr qrf can be chosen by other criteria
           ! (eg speed by replacing global with restricted window pivoting, such
           ! as in sgeqpx from toms # 782). good results will be obtained using
           ! sgeqpx with properly (!) chosen numerical parameters.
           ! any improvement of stdlib_sgeqp3 improves overall performance of stdlib_sgejsv.
           ! a * p1 = q1 * [ r1^t 0]^t:
           do p = 1, n
              ! All Columns Are Free Columns
              iwork(p) = 0_ilp
           end do
           call stdlib_sgeqp3( m,n,a,lda, iwork,work, work(n+1),lwork-n, ierr )
           ! the upper triangular matrix r1 from the first qrf is inspected for
           ! rank deficiency and possibilities for deflation, or possible
           ! ill-conditioning. depending on the user specified flag l2rank,
           ! the procedure explores possibilities to reduce the numerical
           ! rank by inspecting the computed upper triangular factor. if
           ! l2rank or l2aber are up, then stdlib_sgejsv will compute the svd of
           ! a + da, where ||da|| <= f(m,n)*epsln.
           nr = 1_ilp
           if ( l2aber ) then
              ! standard absolute error bound suffices. all sigma_i with
              ! sigma_i < n*epsln*||a|| are flushed to zero. this is an
              ! aggressive enforcement of lower numerical rank by introducing a
              ! backward error of the order of n*epsln*||a||.
              temp1 = sqrt(real(n,KIND=sp))*epsln
              do p = 2, n
                 if ( abs(a(p,p)) >= (temp1*abs(a(1_ilp,1_ilp))) ) then
                    nr = nr + 1_ilp
                 else
                    go to 3002
                 end if
              end do
              3002 continue
           else if ( l2rank ) then
              ! .. similarly as above, only slightly more gentle (less aggressive).
              ! sudden drop on the diagonal of r1 is used as the criterion for
              ! close-to-rank-deficient.
              temp1 = sqrt(sfmin)
              do p = 2, n
                 if ( ( abs(a(p,p)) < (epsln*abs(a(p-1,p-1))) ) .or.( abs(a(p,p)) < small ) .or.( &
                           l2kill .and. (abs(a(p,p)) < temp1) ) ) go to 3402
                 nr = nr + 1_ilp
              end do
              3402 continue
           else
              ! the goal is high relative accuracy. however, if the matrix
              ! has high scaled condition number the relative accuracy is in
              ! general not feasible. later on, a condition number estimator
              ! will be deployed to estimate the scaled condition number.
              ! here we just remove the underflowed part of the triangular
              ! factor. this prevents the situation in which the code is
              ! working hard to get the accuracy not warranted by the data.
              temp1  = sqrt(sfmin)
              do p = 2, n
                 if ( ( abs(a(p,p)) < small ) .or.( l2kill .and. (abs(a(p,p)) < temp1) ) ) go to 3302
                 nr = nr + 1_ilp
              end do
              3302 continue
           end if
           almort = .false.
           if ( nr == n ) then
              maxprj = one
              do p = 2, n
                 temp1  = abs(a(p,p)) / sva(iwork(p))
                 maxprj = min( maxprj, temp1 )
              end do
              if ( maxprj**2_ilp >= one - real(n,KIND=sp)*epsln ) almort = .true.
           end if
           sconda = - one
           condr1 = - one
           condr2 = - one
           if ( errest ) then
              if ( n == nr ) then
                 if ( rsvec ) then
                    ! V Is Available As Workspace
                    call stdlib_slacpy( 'U', n, n, a, lda, v, ldv )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_sscal( p, one/temp1, v(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_spocon( 'U', n, v, ldv, one, temp1,work(n+1), iwork(2_ilp*n+m+1), &
                              ierr )
                 else if ( lsvec ) then
                    ! U Is Available As Workspace
                    call stdlib_slacpy( 'U', n, n, a, lda, u, ldu )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_sscal( p, one/temp1, u(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_spocon( 'U', n, u, ldu, one, temp1,work(n+1), iwork(2_ilp*n+m+1), &
                              ierr )
                 else
                    call stdlib_slacpy( 'U', n, n, a, lda, work(n+1), n )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_sscal( p, one/temp1, work(n+(p-1)*n+1), 1_ilp )
                    end do
                 ! The Columns Of R Are Scaled To Have Unit Euclidean Lengths
                    call stdlib_spocon( 'U', n, work(n+1), n, one, temp1,work(n+n*n+1), iwork(2_ilp*n+&
                              m+1), ierr )
                 end if
                 sconda = one / sqrt(temp1)
                 ! sconda is an estimate of sqrt(||(r^t * r)^(-1)||_1).
                 ! n^(-1/4) * sconda <= ||r^(-1)||_2 <= n^(1/4) * sconda
              else
                 sconda = - one
              end if
           end if
           l2pert = l2pert .and. ( abs( a(1_ilp,1_ilp)/a(nr,nr) ) > sqrt(big1) )
           ! if there is no violent scaling, artificial perturbation is not needed.
           ! phase 3:
           if ( .not. ( rsvec .or. lsvec ) ) then
               ! singular values only
               ! .. transpose a(1:nr,1:n)
              do p = 1, min( n-1, nr )
                 call stdlib_scopy( n-p, a(p,p+1), lda, a(p+1,p), 1_ilp )
              end do
              ! the following two do-loops introduce small relative perturbation
              ! into the strict upper triangle of the lower triangular matrix.
              ! small entries below the main diagonal are also changed.
              ! this modification is useful if the computing environment does not
              ! provide/allow flush to zero underflow, for it prevents many
              ! annoying denormalized numbers in case of strongly scaled matrices.
              ! the perturbation is structured so that it does not introduce any
              ! new perturbation of the singular values, and it does not destroy
              ! the job done by the preconditioner.
              ! the licence for this perturbation is in the variable l2pert, which
              ! should be .false. if flush to zero underflow is active.
              if ( .not. almort ) then
                 if ( l2pert ) then
                    ! xsc = sqrt(small)
                    xsc = epsln / real(n,KIND=sp)
                    do q = 1, nr
                       temp1 = xsc*abs(a(q,q))
                       do p = 1, n
                          if ( ( (p>q) .and. (abs(a(p,q))<=temp1) ).or. ( p < q ) )a(p,q) = sign( &
                                    temp1, a(p,q) )
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_slaset( 'U', nr-1,nr-1, zero,zero, a(1_ilp,2_ilp),lda )
                 end if
                  ! Second Preconditioning Using The Qr Factorization
                 call stdlib_sgeqrf( n,nr, a,lda, work, work(n+1),lwork-n, ierr )
                 ! And Transpose Upper To Lower Triangular
                 do p = 1, nr - 1
                    call stdlib_scopy( nr-p, a(p,p+1), lda, a(p+1,p), 1_ilp )
                 end do
              end if
                 ! row-cyclic jacobi svd algorithm with column pivoting
                 ! .. again some perturbation (a "background noise") is added
                 ! to drown denormals
                 if ( l2pert ) then
                    ! xsc = sqrt(small)
                    xsc = epsln / real(n,KIND=sp)
                    do q = 1, nr
                       temp1 = xsc*abs(a(q,q))
                       do p = 1, nr
                          if ( ( (p>q) .and. (abs(a(p,q))<=temp1) ).or. ( p < q ) )a(p,q) = sign( &
                                    temp1, a(p,q) )
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_slaset( 'U', nr-1, nr-1, zero, zero, a(1_ilp,2_ilp), lda )
                 end if
                 ! .. and one-sided jacobi rotations are started on a lower
                 ! triangular matrix (plus perturbation which is ignored in
                 ! the part which destroys triangular form (confusing?!))
                 call stdlib_sgesvj( 'L', 'NOU', 'NOV', nr, nr, a, lda, sva,n, v, ldv, work, &
                           lwork, info )
                 scalem  = work(1_ilp)
                 numrank = nint(work(2_ilp),KIND=ilp)
           else if ( rsvec .and. ( .not. lsvec ) ) then
              ! -> singular values and right singular vectors <-
              if ( almort ) then
                 ! In This Case Nr Equals N
                 do p = 1, nr
                    call stdlib_scopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                 end do
                 if (nr>1_ilp) call stdlib_slaset( 'UPPER', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
                 call stdlib_sgesvj( 'L','U','N', n, nr, v,ldv, sva, nr, a,lda,work, lwork, info )
                           
                 scalem  = work(1_ilp)
                 numrank = nint(work(2_ilp),KIND=ilp)
              else
              ! .. two more qr factorizations ( one qrf is not enough, two require
              ! accumulated product of jacobi rotations, three are perfect )
                 if (nr>1_ilp) call stdlib_slaset( 'LOWER', nr-1, nr-1, zero, zero, a(2_ilp,1_ilp), lda )
                 call stdlib_sgelqf( nr, n, a, lda, work, work(n+1), lwork-n, ierr)
                 call stdlib_slacpy( 'LOWER', nr, nr, a, lda, v, ldv )
                 if (nr>1_ilp) call stdlib_slaset( 'UPPER', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
                 call stdlib_sgeqrf( nr, nr, v, ldv, work(n+1), work(2_ilp*n+1),lwork-2*n, ierr )
                           
                 do p = 1, nr
                    call stdlib_scopy( nr-p+1, v(p,p), ldv, v(p,p), 1_ilp )
                 end do
                 if (nr>1_ilp) call stdlib_slaset( 'UPPER', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
                 call stdlib_sgesvj( 'LOWER', 'U','N', nr, nr, v,ldv, sva, nr, u,ldu, work(n+1), &
                           lwork-n, info )
                 scalem  = work(n+1)
                 numrank = nint(work(n+2),KIND=ilp)
                 if ( nr < n ) then
                    call stdlib_slaset( 'A',n-nr, nr, zero,zero, v(nr+1,1_ilp),   ldv )
                    call stdlib_slaset( 'A',nr, n-nr, zero,zero, v(1_ilp,nr+1),   ldv )
                    call stdlib_slaset( 'A',n-nr,n-nr,zero,one, v(nr+1,nr+1), ldv )
                 end if
              call stdlib_sormlq( 'LEFT', 'TRANSPOSE', n, n, nr, a, lda, work,v, ldv, work(n+1), &
                        lwork-n, ierr )
              end if
              do p = 1, n
                 call stdlib_scopy( n, v(p,1_ilp), ldv, a(iwork(p),1_ilp), lda )
              end do
              call stdlib_slacpy( 'ALL', n, n, a, lda, v, ldv )
              if ( transp ) then
                 call stdlib_slacpy( 'ALL', n, n, v, ldv, u, ldu )
              end if
           else if ( lsvec .and. ( .not. rsvec ) ) then
              ! Singular Values And Left Singular Vectors                 
              ! Second Preconditioning Step To Avoid Need To Accumulate
              ! jacobi rotations in the jacobi iterations.
              do p = 1, nr
                 call stdlib_scopy( n-p+1, a(p,p), lda, u(p,p), 1_ilp )
              end do
              if (nr>1_ilp) call stdlib_slaset( 'UPPER', nr-1, nr-1, zero, zero, u(1_ilp,2_ilp), ldu )
              call stdlib_sgeqrf( n, nr, u, ldu, work(n+1), work(2_ilp*n+1),lwork-2*n, ierr )
              do p = 1, nr - 1
                 call stdlib_scopy( nr-p, u(p,p+1), ldu, u(p+1,p), 1_ilp )
              end do
              if (nr>1_ilp) call stdlib_slaset( 'UPPER', nr-1, nr-1, zero, zero, u(1_ilp,2_ilp), ldu )
              call stdlib_sgesvj( 'LOWER', 'U', 'N', nr,nr, u, ldu, sva, nr, a,lda, work(n+1), &
                        lwork-n, info )
              scalem  = work(n+1)
              numrank = nint(work(n+2),KIND=ilp)
              if ( nr < m ) then
                 call stdlib_slaset( 'A',  m-nr, nr,zero, zero, u(nr+1,1_ilp), ldu )
                 if ( nr < n1 ) then
                    call stdlib_slaset( 'A',nr, n1-nr, zero, zero, u(1_ilp,nr+1), ldu )
                    call stdlib_slaset( 'A',m-nr,n1-nr,zero,one,u(nr+1,nr+1), ldu )
                 end if
              end if
              call stdlib_sormqr( 'LEFT', 'NO TR', m, n1, n, a, lda, work, u,ldu, work(n+1), &
                        lwork-n, ierr )
              if ( rowpiv )call stdlib_slaswp( n1, u, ldu, 1_ilp, m-1, iwork(2_ilp*n+1), -1_ilp )
              do p = 1, n1
                 xsc = one / stdlib_snrm2( m, u(1_ilp,p), 1_ilp )
                 call stdlib_sscal( m, xsc, u(1_ilp,p), 1_ilp )
              end do
              if ( transp ) then
                 call stdlib_slacpy( 'ALL', n, n, u, ldu, v, ldv )
              end if
           else
              ! Full Svd 
              if ( .not. jracc ) then
              if ( .not. almort ) then
                 ! second preconditioning step (qrf [with pivoting])
                 ! note that the composition of transpose, qrf and transpose is
                 ! equivalent to an lqf call. since in many libraries the qrf
                 ! seems to be better optimized than the lqf, we do explicit
                 ! transpose and use the qrf. this is subject to changes in an
                 ! optimized implementation of stdlib_sgejsv.
                 do p = 1, nr
                    call stdlib_scopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                 end do
                 ! The Following Two Loops Perturb Small Entries To Avoid
                 ! denormals in the second qr factorization, where they are
                 ! as good as zeros. this is done to avoid painfully slow
                 ! computation with denormals. the relative size of the perturbation
                 ! is a parameter that can be changed by the implementer.
                 ! this perturbation device will be obsolete on machines with
                 ! properly implemented arithmetic.
                 ! to switch it off, set l2pert=.false. to remove it from  the
                 ! code, remove the action under l2pert=.true., leave the else part.
                 ! the following two loops should be blocked and fused with the
                 ! transposed copy above.
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do q = 1, nr
                       temp1 = xsc*abs( v(q,q) )
                       do p = 1, n
                          if ( ( p > q ) .and. ( abs(v(p,q)) <= temp1 ).or. ( p < q ) )v(p,q) = &
                                    sign( temp1, v(p,q) )
                          if ( p < q ) v(p,q) = - v(p,q)
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_slaset( 'U', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
                 end if
                 ! estimate the row scaled condition number of r1
                 ! (if r1 is rectangular, n > nr, then the condition number
                 ! of the leading nr x nr submatrix is estimated.)
                 call stdlib_slacpy( 'L', nr, nr, v, ldv, work(2_ilp*n+1), nr )
                 do p = 1, nr
                    temp1 = stdlib_snrm2(nr-p+1,work(2_ilp*n+(p-1)*nr+p),1_ilp)
                    call stdlib_sscal(nr-p+1,one/temp1,work(2_ilp*n+(p-1)*nr+p),1_ilp)
                 end do
                 call stdlib_spocon('LOWER',nr,work(2_ilp*n+1),nr,one,temp1,work(2_ilp*n+nr*nr+1),iwork(m+&
                           2_ilp*n+1),ierr)
                 condr1 = one / sqrt(temp1)
                 ! Here Need A Second Opinion On The Condition Number
                 ! Then Assume Worst Case Scenario
                 ! r1 is ok for inverse <=> condr1 < real(n,KIND=sp)
                 ! more conservative    <=> condr1 < sqrt(real(n,KIND=sp))
                 cond_ok = sqrt(real(nr,KIND=sp))
      ! [tp]       cond_ok is a tuning parameter.
                 if ( condr1 < cond_ok ) then
                    ! .. the second qrf without pivoting. note: in an optimized
                    ! implementation, this qrf should be implemented as the qrf
                    ! of a lower triangular matrix.
                    ! r1^t = q2 * r2
                    call stdlib_sgeqrf( n, nr, v, ldv, work(n+1), work(2_ilp*n+1),lwork-2*n, ierr )
                              
                    if ( l2pert ) then
                       xsc = sqrt(small)/epsln
                       do p = 2, nr
                          do q = 1, p - 1
                             temp1 = xsc * min(abs(v(p,p)),abs(v(q,q)))
                             if ( abs(v(q,p)) <= temp1 )v(q,p) = sign( temp1, v(q,p) )
                          end do
                       end do
                    end if
                    if ( nr /= n )call stdlib_slacpy( 'A', n, nr, v, ldv, work(2_ilp*n+1), n )
                    ! .. save ...
                 ! This Transposed Copy Should Be Better Than Naive
                    do p = 1, nr - 1
                       call stdlib_scopy( nr-p, v(p,p+1), ldv, v(p+1,p), 1_ilp )
                    end do
                    condr2 = condr1
                 else
                    ! .. ill-conditioned case: second qrf with pivoting
                    ! note that windowed pivoting would be equally good
                    ! numerically, and more run-time efficient. so, in
                    ! an optimal implementation, the next call to stdlib_sgeqp3
                    ! should be replaced with eg. call sgeqpx (acm toms #782)
                    ! with properly (carefully) chosen parameters.
                    ! r1^t * p2 = q2 * r2
                    do p = 1, nr
                       iwork(n+p) = 0_ilp
                    end do
                    call stdlib_sgeqp3( n, nr, v, ldv, iwork(n+1), work(n+1),work(2_ilp*n+1), lwork-&
                              2_ilp*n, ierr )
      ! *               call stdlib_sgeqrf( n, nr, v, ldv, work(n+1), work(2*n+1),
      ! *     $              lwork-2*n, ierr )
                    if ( l2pert ) then
                       xsc = sqrt(small)
                       do p = 2, nr
                          do q = 1, p - 1
                             temp1 = xsc * min(abs(v(p,p)),abs(v(q,q)))
                             if ( abs(v(q,p)) <= temp1 )v(q,p) = sign( temp1, v(q,p) )
                          end do
                       end do
                    end if
                    call stdlib_slacpy( 'A', n, nr, v, ldv, work(2_ilp*n+1), n )
                    if ( l2pert ) then
                       xsc = sqrt(small)
                       do p = 2, nr
                          do q = 1, p - 1
                             temp1 = xsc * min(abs(v(p,p)),abs(v(q,q)))
                             v(p,q) = - sign( temp1, v(q,p) )
                          end do
                       end do
                    else
                       if (nr>1_ilp) call stdlib_slaset( 'L',nr-1,nr-1,zero,zero,v(2_ilp,1_ilp),ldv )
                    end if
                    ! now, compute r2 = l3 * q3, the lq factorization.
                    call stdlib_sgelqf( nr, nr, v, ldv, work(2_ilp*n+n*nr+1),work(2_ilp*n+n*nr+nr+1), &
                              lwork-2*n-n*nr-nr, ierr )
                    ! And Estimate The Condition Number
                    call stdlib_slacpy( 'L',nr,nr,v,ldv,work(2_ilp*n+n*nr+nr+1),nr )
                    do p = 1, nr
                       temp1 = stdlib_snrm2( p, work(2_ilp*n+n*nr+nr+p), nr )
                       call stdlib_sscal( p, one/temp1, work(2_ilp*n+n*nr+nr+p), nr )
                    end do
                    call stdlib_spocon( 'L',nr,work(2_ilp*n+n*nr+nr+1),nr,one,temp1,work(2_ilp*n+n*nr+nr+&
                              nr*nr+1),iwork(m+2*n+1),ierr )
                    condr2 = one / sqrt(temp1)
                    if ( condr2 >= cond_ok ) then
                       ! Save The Householder Vectors Used For Q3
                       ! (this overwrites the copy of r2, as it will not be
                       ! needed in this branch, but it does not overwritte the
                       ! huseholder vectors of q2.).
                       call stdlib_slacpy( 'U', nr, nr, v, ldv, work(2_ilp*n+1), n )
                       ! And The Rest Of The Information On Q3 Is In
                       ! work(2*n+n*nr+1:2*n+n*nr+n)
                    end if
                 end if
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do q = 2, nr
                       temp1 = xsc * v(q,q)
                       do p = 1, q - 1
                          ! v(p,q) = - sign( temp1, v(q,p) )
                          v(p,q) = - sign( temp1, v(p,q) )
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_slaset( 'U', nr-1,nr-1, zero,zero, v(1_ilp,2_ilp), ldv )
                 end if
              ! second preconditioning finished; continue with jacobi svd
              ! the input matrix is lower trinagular.
              ! recover the right singular vectors as solution of a well
              ! conditioned triangular matrix equation.
                 if ( condr1 < cond_ok ) then
                    call stdlib_sgesvj( 'L','U','N',nr,nr,v,ldv,sva,nr,u,ldu,work(2_ilp*n+n*nr+nr+1),&
                              lwork-2*n-n*nr-nr,info )
                    scalem  = work(2_ilp*n+n*nr+nr+1)
                    numrank = nint(work(2_ilp*n+n*nr+nr+2),KIND=ilp)
                    do p = 1, nr
                       call stdlib_scopy( nr, v(1_ilp,p), 1_ilp, u(1_ilp,p), 1_ilp )
                       call stdlib_sscal( nr, sva(p),    v(1_ilp,p), 1_ilp )
                    end do
              ! Pick The Right Matrix Equation And Solve It
                    if ( nr == n ) then
       ! :))             .. best case, r1 is inverted. the solution of this matrix
                       ! equation is q2*v2 = the product of the jacobi rotations
                       ! used in stdlib_sgesvj, premultiplied with the orthogonal matrix
                       ! from the second qr factorization.
                       call stdlib_strsm( 'L','U','N','N', nr,nr,one, a,lda, v,ldv )
                    else
                       ! .. r1 is well conditioned, but non-square. transpose(r2)
                       ! is inverted to get the product of the jacobi rotations
                       ! used in stdlib_sgesvj. the q-factor from the second qr
                       ! factorization is then built in explicitly.
                       call stdlib_strsm('L','U','T','N',nr,nr,one,work(2_ilp*n+1),n,v,ldv)
                       if ( nr < n ) then
                         call stdlib_slaset('A',n-nr,nr,zero,zero,v(nr+1,1_ilp),ldv)
                         call stdlib_slaset('A',nr,n-nr,zero,zero,v(1_ilp,nr+1),ldv)
                         call stdlib_slaset('A',n-nr,n-nr,zero,one,v(nr+1,nr+1),ldv)
                       end if
                       call stdlib_sormqr('L','N',n,n,nr,work(2_ilp*n+1),n,work(n+1),v,ldv,work(2_ilp*n+&
                                 n*nr+nr+1),lwork-2*n-n*nr-nr,ierr)
                    end if
                 else if ( condr2 < cond_ok ) then
       ! :)           .. the input matrix a is very likely a relative of
                    ! the kahan matrix :)
                    ! the matrix r2 is inverted. the solution of the matrix equation
                    ! is q3^t*v3 = the product of the jacobi rotations (appplied to
                    ! the lower triangular l3 from the lq factorization of
                    ! r2=l3*q3), pre-multiplied with the transposed q3.
                    call stdlib_sgesvj( 'L', 'U', 'N', nr, nr, v, ldv, sva, nr, u,ldu, work(2_ilp*n+&
                              n*nr+nr+1), lwork-2*n-n*nr-nr, info )
                    scalem  = work(2_ilp*n+n*nr+nr+1)
                    numrank = nint(work(2_ilp*n+n*nr+nr+2),KIND=ilp)
                    do p = 1, nr
                       call stdlib_scopy( nr, v(1_ilp,p), 1_ilp, u(1_ilp,p), 1_ilp )
                       call stdlib_sscal( nr, sva(p),    u(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_strsm('L','U','N','N',nr,nr,one,work(2_ilp*n+1),n,u,ldu)
                    ! Apply The Permutation From The Second Qr Factorization
                    do q = 1, nr
                       do p = 1, nr
                          work(2_ilp*n+n*nr+nr+iwork(n+p)) = u(p,q)
                       end do
                       do p = 1, nr
                          u(p,q) = work(2_ilp*n+n*nr+nr+p)
                       end do
                    end do
                    if ( nr < n ) then
                       call stdlib_slaset( 'A',n-nr,nr,zero,zero,v(nr+1,1_ilp),ldv )
                       call stdlib_slaset( 'A',nr,n-nr,zero,zero,v(1_ilp,nr+1),ldv )
                       call stdlib_slaset( 'A',n-nr,n-nr,zero,one,v(nr+1,nr+1),ldv )
                    end if
                    call stdlib_sormqr( 'L','N',n,n,nr,work(2_ilp*n+1),n,work(n+1),v,ldv,work(2_ilp*n+&
                              n*nr+nr+1),lwork-2*n-n*nr-nr,ierr )
                 else
                    ! last line of defense.
       ! #:(          this is a rather pathological case: no scaled condition
                    ! improvement after two pivoted qr factorizations. other
                    ! possibility is that the rank revealing qr factorization
                    ! or the condition estimator has failed, or the cond_ok
                    ! is set very close to one (which is unnecessary). normally,
                    ! this branch should never be executed, but in rare cases of
                    ! failure of the rrqr or condition estimator, the last line of
                    ! defense ensures that stdlib_sgejsv completes the task.
                    ! compute the full svd of l3 using stdlib_sgesvj with explicit
                    ! accumulation of jacobi rotations.
                    call stdlib_sgesvj( 'L', 'U', 'V', nr, nr, v, ldv, sva, nr, u,ldu, work(2_ilp*n+&
                              n*nr+nr+1), lwork-2*n-n*nr-nr, info )
                    scalem  = work(2_ilp*n+n*nr+nr+1)
                    numrank = nint(work(2_ilp*n+n*nr+nr+2),KIND=ilp)
                    if ( nr < n ) then
                       call stdlib_slaset( 'A',n-nr,nr,zero,zero,v(nr+1,1_ilp),ldv )
                       call stdlib_slaset( 'A',nr,n-nr,zero,zero,v(1_ilp,nr+1),ldv )
                       call stdlib_slaset( 'A',n-nr,n-nr,zero,one,v(nr+1,nr+1),ldv )
                    end if
                    call stdlib_sormqr( 'L','N',n,n,nr,work(2_ilp*n+1),n,work(n+1),v,ldv,work(2_ilp*n+&
                              n*nr+nr+1),lwork-2*n-n*nr-nr,ierr )
                    call stdlib_sormlq( 'L', 'T', nr, nr, nr, work(2_ilp*n+1), n,work(2_ilp*n+n*nr+1), u, &
                              ldu, work(2_ilp*n+n*nr+nr+1),lwork-2*n-n*nr-nr, ierr )
                    do q = 1, nr
                       do p = 1, nr
                          work(2_ilp*n+n*nr+nr+iwork(n+p)) = u(p,q)
                       end do
                       do p = 1, nr
                          u(p,q) = work(2_ilp*n+n*nr+nr+p)
                       end do
                    end do
                 end if
                 ! permute the rows of v using the (column) permutation from the
                 ! first qrf. also, scale the columns to make them unit in
                 ! euclidean norm. this applies to all cases.
                 temp1 = sqrt(real(n,KIND=sp)) * epsln
                 do q = 1, n
                    do p = 1, n
                       work(2_ilp*n+n*nr+nr+iwork(p)) = v(p,q)
                    end do
                    do p = 1, n
                       v(p,q) = work(2_ilp*n+n*nr+nr+p)
                    end do
                    xsc = one / stdlib_snrm2( n, v(1_ilp,q), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_sscal( n, xsc, &
                              v(1_ilp,q), 1_ilp )
                 end do
                 ! at this moment, v contains the right singular vectors of a.
                 ! next, assemble the left singular vector matrix u (m x n).
                 if ( nr < m ) then
                    call stdlib_slaset( 'A', m-nr, nr, zero, zero, u(nr+1,1_ilp), ldu )
                    if ( nr < n1 ) then
                       call stdlib_slaset('A',nr,n1-nr,zero,zero,u(1_ilp,nr+1),ldu)
                       call stdlib_slaset('A',m-nr,n1-nr,zero,one,u(nr+1,nr+1),ldu)
                    end if
                 end if
                 ! the q matrix from the first qrf is built into the left singular
                 ! matrix u. this applies to all cases.
                 call stdlib_sormqr( 'LEFT', 'NO_TR', m, n1, n, a, lda, work, u,ldu, work(n+1), &
                           lwork-n, ierr )
                 ! the columns of u are normalized. the cost is o(m*n) flops.
                 temp1 = sqrt(real(m,KIND=sp)) * epsln
                 do p = 1, nr
                    xsc = one / stdlib_snrm2( m, u(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_sscal( m, xsc, &
                              u(1_ilp,p), 1_ilp )
                 end do
                 ! if the initial qrf is computed with row pivoting, the left
                 ! singular vectors must be adjusted.
                 if ( rowpiv )call stdlib_slaswp( n1, u, ldu, 1_ilp, m-1, iwork(2_ilp*n+1), -1_ilp )
              else
              ! The Initial Matrix A Has Almost Orthogonal Columns And
              ! the second qrf is not needed
                 call stdlib_slacpy( 'UPPER', n, n, a, lda, work(n+1), n )
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do p = 2, n
                       temp1 = xsc * work( n + (p-1)*n + p )
                       do q = 1, p - 1
                          work(n+(q-1)*n+p)=-sign(temp1,work(n+(p-1)*n+q))
                       end do
                    end do
                 else
                    call stdlib_slaset( 'LOWER',n-1,n-1,zero,zero,work(n+2),n )
                 end if
                 call stdlib_sgesvj( 'UPPER', 'U', 'N', n, n, work(n+1), n, sva,n, u, ldu, work(n+&
                           n*n+1), lwork-n-n*n, info )
                 scalem  = work(n+n*n+1)
                 numrank = nint(work(n+n*n+2),KIND=ilp)
                 do p = 1, n
                    call stdlib_scopy( n, work(n+(p-1)*n+1), 1_ilp, u(1_ilp,p), 1_ilp )
                    call stdlib_sscal( n, sva(p), work(n+(p-1)*n+1), 1_ilp )
                 end do
                 call stdlib_strsm( 'LEFT', 'UPPER', 'NOTRANS', 'NO UD', n, n,one, a, lda, work(n+&
                           1_ilp), n )
                 do p = 1, n
                    call stdlib_scopy( n, work(n+p), n, v(iwork(p),1_ilp), ldv )
                 end do
                 temp1 = sqrt(real(n,KIND=sp))*epsln
                 do p = 1, n
                    xsc = one / stdlib_snrm2( n, v(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_sscal( n, xsc, &
                              v(1_ilp,p), 1_ilp )
                 end do
                 ! assemble the left singular vector matrix u (m x n).
                 if ( n < m ) then
                    call stdlib_slaset( 'A',  m-n, n, zero, zero, u(n+1,1_ilp), ldu )
                    if ( n < n1 ) then
                       call stdlib_slaset( 'A',n,  n1-n, zero, zero,  u(1_ilp,n+1),ldu )
                       call stdlib_slaset( 'A',m-n,n1-n, zero, one,u(n+1,n+1),ldu )
                    end if
                 end if
                 call stdlib_sormqr( 'LEFT', 'NO TR', m, n1, n, a, lda, work, u,ldu, work(n+1), &
                           lwork-n, ierr )
                 temp1 = sqrt(real(m,KIND=sp))*epsln
                 do p = 1, n1
                    xsc = one / stdlib_snrm2( m, u(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_sscal( m, xsc, &
                              u(1_ilp,p), 1_ilp )
                 end do
                 if ( rowpiv )call stdlib_slaswp( n1, u, ldu, 1_ilp, m-1, iwork(2_ilp*n+1), -1_ilp )
              end if
              ! end of the  >> almost orthogonal case <<  in the full svd
              else
              ! this branch deploys a preconditioned jacobi svd with explicitly
              ! accumulated rotations. it is included as optional, mainly for
              ! experimental purposes. it does perform well, and can also be used.
              ! in this implementation, this branch will be automatically activated
              ! if the  condition number sigma_max(a) / sigma_min(a) is predicted
              ! to be greater than the overflow threshold. this is because the
              ! a posteriori computation of the singular vectors assumes robust
              ! implementation of blas and some lapack procedures, capable of working
              ! in presence of extreme values. since that is not always the case, ...
              do p = 1, nr
                 call stdlib_scopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
              end do
              if ( l2pert ) then
                 xsc = sqrt(small/epsln)
                 do q = 1, nr
                    temp1 = xsc*abs( v(q,q) )
                    do p = 1, n
                       if ( ( p > q ) .and. ( abs(v(p,q)) <= temp1 ).or. ( p < q ) )v(p,q) = sign(&
                                  temp1, v(p,q) )
                       if ( p < q ) v(p,q) = - v(p,q)
                    end do
                 end do
              else
                 if (nr>1_ilp) call stdlib_slaset( 'U', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
              end if
              call stdlib_sgeqrf( n, nr, v, ldv, work(n+1), work(2_ilp*n+1),lwork-2*n, ierr )
              call stdlib_slacpy( 'L', n, nr, v, ldv, work(2_ilp*n+1), n )
              do p = 1, nr
                 call stdlib_scopy( nr-p+1, v(p,p), ldv, u(p,p), 1_ilp )
              end do
              if ( l2pert ) then
                 xsc = sqrt(small/epsln)
                 do q = 2, nr
                    do p = 1, q - 1
                       temp1 = xsc * min(abs(u(p,p)),abs(u(q,q)))
                       u(p,q) = - sign( temp1, u(q,p) )
                    end do
                 end do
              else
                 if (nr>1_ilp) call stdlib_slaset('U', nr-1, nr-1, zero, zero, u(1_ilp,2_ilp), ldu )
              end if
              call stdlib_sgesvj( 'L', 'U', 'V', nr, nr, u, ldu, sva,n, v, ldv, work(2_ilp*n+n*nr+1), &
                        lwork-2*n-n*nr, info )
              scalem  = work(2_ilp*n+n*nr+1)
              numrank = nint(work(2_ilp*n+n*nr+2),KIND=ilp)
              if ( nr < n ) then
                 call stdlib_slaset( 'A',n-nr,nr,zero,zero,v(nr+1,1_ilp),ldv )
                 call stdlib_slaset( 'A',nr,n-nr,zero,zero,v(1_ilp,nr+1),ldv )
                 call stdlib_slaset( 'A',n-nr,n-nr,zero,one,v(nr+1,nr+1),ldv )
              end if
              call stdlib_sormqr( 'L','N',n,n,nr,work(2_ilp*n+1),n,work(n+1),v,ldv,work(2_ilp*n+n*nr+nr+1)&
                        ,lwork-2*n-n*nr-nr,ierr )
                 ! permute the rows of v using the (column) permutation from the
                 ! first qrf. also, scale the columns to make them unit in
                 ! euclidean norm. this applies to all cases.
                 temp1 = sqrt(real(n,KIND=sp)) * epsln
                 do q = 1, n
                    do p = 1, n
                       work(2_ilp*n+n*nr+nr+iwork(p)) = v(p,q)
                    end do
                    do p = 1, n
                       v(p,q) = work(2_ilp*n+n*nr+nr+p)
                    end do
                    xsc = one / stdlib_snrm2( n, v(1_ilp,q), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_sscal( n, xsc, &
                              v(1_ilp,q), 1_ilp )
                 end do
                 ! at this moment, v contains the right singular vectors of a.
                 ! next, assemble the left singular vector matrix u (m x n).
              if ( nr < m ) then
                 call stdlib_slaset( 'A',  m-nr, nr, zero, zero, u(nr+1,1_ilp), ldu )
                 if ( nr < n1 ) then
                    call stdlib_slaset( 'A',nr,  n1-nr, zero, zero,  u(1_ilp,nr+1),ldu )
                    call stdlib_slaset( 'A',m-nr,n1-nr, zero, one,u(nr+1,nr+1),ldu )
                 end if
              end if
              call stdlib_sormqr( 'LEFT', 'NO TR', m, n1, n, a, lda, work, u,ldu, work(n+1), &
                        lwork-n, ierr )
                 if ( rowpiv )call stdlib_slaswp( n1, u, ldu, 1_ilp, m-1, iwork(2_ilp*n+1), -1_ilp )
              end if
              if ( transp ) then
                 ! .. swap u and v because the procedure worked on a^t
                 do p = 1, n
                    call stdlib_sswap( n, u(1_ilp,p), 1_ilp, v(1_ilp,p), 1_ilp )
                 end do
              end if
           end if
           ! end of the full svd
           ! undo scaling, if necessary (and possible)
           if ( uscal2 <= (big/sva(1_ilp))*uscal1 ) then
              call stdlib_slascl( 'G', 0_ilp, 0_ilp, uscal1, uscal2, nr, 1_ilp, sva, n, ierr )
              uscal1 = one
              uscal2 = one
           end if
           if ( nr < n ) then
              do p = nr+1, n
                 sva(p) = zero
              end do
           end if
           work(1_ilp) = uscal2 * scalem
           work(2_ilp) = uscal1
           if ( errest ) work(3_ilp) = sconda
           if ( lsvec .and. rsvec ) then
              work(4_ilp) = condr1
              work(5_ilp) = condr2
           end if
           if ( l2tran ) then
              work(6_ilp) = entra
              work(7_ilp) = entrat
           end if
           iwork(1_ilp) = nr
           iwork(2_ilp) = numrank
           iwork(3_ilp) = warning
           return
     end subroutine stdlib_sgejsv

     pure module subroutine stdlib_dgejsv( joba, jobu, jobv, jobr, jobt, jobp,m, n, a, lda, sva, u, ldu, &
     !! DGEJSV computes the singular value decomposition (SVD) of a real M-by-N
     !! matrix [A], where M >= N. The SVD of [A] is written as
     !! [A] = [U] * [SIGMA] * [V]^t,
     !! where [SIGMA] is an N-by-N (M-by-N) matrix which is zero except for its N
     !! diagonal elements, [U] is an M-by-N (or M-by-M) orthonormal matrix, and
     !! [V] is an N-by-N orthogonal matrix. The diagonal elements of [SIGMA] are
     !! the singular values of [A]. The columns of [U] and [V] are the left and
     !! the right singular vectors of [A], respectively. The matrices [U] and [V]
     !! are computed and stored in the arrays U and V, respectively. The diagonal
     !! of [SIGMA] is computed and stored in the array SVA.
     !! DGEJSV can sometimes compute tiny singular values and their singular vectors much
     !! more accurately than other SVD routines, see below under Further Details.
               v, ldv,work, lwork, iwork, info )
        ! -- lapack computational routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_dp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldu, ldv, lwork, m, n
           ! Array Arguments 
           real(dp), intent(inout) :: a(lda,*)
           real(dp), intent(out) :: sva(n), u(ldu,*), v(ldv,*), work(lwork)
           integer(ilp), intent(out) :: iwork(*)
           character, intent(in) :: joba, jobp, jobr, jobt, jobu, jobv
        ! ===========================================================================
           
           ! Local Scalars 
           real(dp) :: aapp, aaqq, aatmax, aatmin, big, big1, cond_ok, condr1, condr2, entra, &
                     entrat, epsln, maxprj, scalem, sconda, sfmin, small, temp1, uscal1, uscal2, xsc
           integer(ilp) :: ierr, n1, nr, numrank, p, q, warning
           logical(lk) :: almort, defr, errest, goscal, jracc, kill, lsvec, l2aber, l2kill, &
                     l2pert, l2rank, l2tran, noscal, rowpiv, rsvec, transp
           ! Intrinsic Functions 
           ! test the input arguments
           lsvec  = stdlib_lsame( jobu, 'U' ) .or. stdlib_lsame( jobu, 'F' )
           jracc  = stdlib_lsame( jobv, 'J' )
           rsvec  = stdlib_lsame( jobv, 'V' ) .or. jracc
           rowpiv = stdlib_lsame( joba, 'F' ) .or. stdlib_lsame( joba, 'G' )
           l2rank = stdlib_lsame( joba, 'R' )
           l2aber = stdlib_lsame( joba, 'A' )
           errest = stdlib_lsame( joba, 'E' ) .or. stdlib_lsame( joba, 'G' )
           l2tran = stdlib_lsame( jobt, 'T' )
           l2kill = stdlib_lsame( jobr, 'R' )
           defr   = stdlib_lsame( jobr, 'N' )
           l2pert = stdlib_lsame( jobp, 'P' )
           if ( .not.(rowpiv .or. l2rank .or. l2aber .or.errest .or. stdlib_lsame( joba, 'C' ) )) &
                     then
              info = - 1_ilp
           else if ( .not.( lsvec  .or. stdlib_lsame( jobu, 'N' ) .or.stdlib_lsame( jobu, 'W' )) )&
                      then
              info = - 2_ilp
           else if ( .not.( rsvec .or. stdlib_lsame( jobv, 'N' ) .or.stdlib_lsame( jobv, 'W' )) &
                     .or. ( jracc .and. (.not.lsvec) ) ) then
              info = - 3_ilp
           else if ( .not. ( l2kill .or. defr ) )    then
              info = - 4_ilp
           else if ( .not. ( l2tran .or. stdlib_lsame( jobt, 'N' ) ) ) then
              info = - 5_ilp
           else if ( .not. ( l2pert .or. stdlib_lsame( jobp, 'N' ) ) ) then
              info = - 6_ilp
           else if ( m < 0_ilp ) then
              info = - 7_ilp
           else if ( ( n < 0_ilp ) .or. ( n > m ) ) then
              info = - 8_ilp
           else if ( lda < m ) then
              info = - 10_ilp
           else if ( lsvec .and. ( ldu < m ) ) then
              info = - 13_ilp
           else if ( rsvec .and. ( ldv < n ) ) then
              info = - 15_ilp
           else if ( (.not.(lsvec .or. rsvec .or. errest).and.(lwork < max(7_ilp,4_ilp*n+1,2_ilp*m+n))) .or.(&
           .not.(lsvec .or. rsvec) .and. errest .and.(lwork < max(7_ilp,4_ilp*n+n*n,2_ilp*m+n))) .or.(lsvec &
           .and. (.not.rsvec) .and. (lwork < max(7_ilp,2_ilp*m+n,4_ilp*n+1))).or.(rsvec .and. (.not.lsvec) &
           .and. (lwork < max(7_ilp,2_ilp*m+n,4_ilp*n+1))).or.(lsvec .and. rsvec .and. (.not.jracc) .and.(&
           lwork<max(2_ilp*m+n,6_ilp*n+2*n*n))).or. (lsvec .and. rsvec .and. jracc .and.lwork<max(2_ilp*m+n,&
                     4_ilp*n+n*n,2_ilp*n+n*n+6)))then
              info = - 17_ilp
           else
              ! #:)
              info = 0_ilp
           end if
           if ( info /= 0_ilp ) then
             ! #:(
              call stdlib_xerbla( 'DGEJSV', - info )
              return
           end if
           ! quick return for void matrix (y3k safe)
       ! #:)
           if ( ( m == 0_ilp ) .or. ( n == 0_ilp ) ) then
              iwork(1_ilp:3_ilp) = 0_ilp
              work(1_ilp:7_ilp) = 0_ilp
              return
           endif
           ! determine whether the matrix u should be m x n or m x m
           if ( lsvec ) then
              n1 = n
              if ( stdlib_lsame( jobu, 'F' ) ) n1 = m
           end if
           ! set numerical parameters
      ! !    note: make sure stdlib_dlamch() does not fail on the target architecture.
           epsln = stdlib_dlamch('EPSILON')
           sfmin = stdlib_dlamch('SAFEMINIMUM')
           small = sfmin / epsln
           big   = stdlib_dlamch('O')
           ! big   = one / sfmin
           ! initialize sva(1:n) = diag( ||a e_i||_2 )_1^n
      ! (!)  if necessary, scale sva() to protect the largest norm from
           ! overflow. it is possible that this scaling pushes the smallest
           ! column norm left from the underflow threshold (extreme case).
           scalem  = one / sqrt(real(m,KIND=dp)*real(n,KIND=dp))
           noscal  = .true.
           goscal  = .true.
           do p = 1, n
              aapp = zero
              aaqq = one
              call stdlib_dlassq( m, a(1_ilp,p), 1_ilp, aapp, aaqq )
              if ( aapp > big ) then
                 info = - 9_ilp
                 call stdlib_xerbla( 'DGEJSV', -info )
                 return
              end if
              aaqq = sqrt(aaqq)
              if ( ( aapp < (big / aaqq) ) .and. noscal  ) then
                 sva(p)  = aapp * aaqq
              else
                 noscal  = .false.
                 sva(p)  = aapp * ( aaqq * scalem )
                 if ( goscal ) then
                    goscal = .false.
                    call stdlib_dscal( p-1, scalem, sva, 1_ilp )
                 end if
              end if
           end do
           if ( noscal ) scalem = one
           aapp = zero
           aaqq = big
           do p = 1, n
              aapp = max( aapp, sva(p) )
              if ( sva(p) /= zero ) aaqq = min( aaqq, sva(p) )
           end do
           ! quick return for zero m x n matrix
       ! #:)
           if ( aapp == zero ) then
              if ( lsvec ) call stdlib_dlaset( 'G', m, n1, zero, one, u, ldu )
              if ( rsvec ) call stdlib_dlaset( 'G', n, n,  zero, one, v, ldv )
              work(1_ilp) = one
              work(2_ilp) = one
              if ( errest ) work(3_ilp) = one
              if ( lsvec .and. rsvec ) then
                 work(4_ilp) = one
                 work(5_ilp) = one
              end if
              if ( l2tran ) then
                 work(6_ilp) = zero
                 work(7_ilp) = zero
              end if
              iwork(1_ilp) = 0_ilp
              iwork(2_ilp) = 0_ilp
              iwork(3_ilp) = 0_ilp
              return
           end if
           ! issue warning if denormalized column norms detected. override the
           ! high relative accuracy request. issue licence to kill columns
           ! (set them to zero) whose norm is less than sigma_max / big (roughly).
       ! #:(
           warning = 0_ilp
           if ( aaqq <= sfmin ) then
              l2rank = .true.
              l2kill = .true.
              warning = 1_ilp
           end if
           ! quick return for one-column matrix
       ! #:)
           if ( n == 1_ilp ) then
              if ( lsvec ) then
                 call stdlib_dlascl( 'G',0_ilp,0_ilp,sva(1_ilp),scalem, m,1_ilp,a(1_ilp,1_ilp),lda,ierr )
                 call stdlib_dlacpy( 'A', m, 1_ilp, a, lda, u, ldu )
                 ! computing all m left singular vectors of the m x 1 matrix
                 if ( n1 /= n  ) then
                    call stdlib_dgeqrf( m, n, u,ldu, work, work(n+1),lwork-n,ierr )
                    call stdlib_dorgqr( m,n1,1_ilp, u,ldu,work,work(n+1),lwork-n,ierr )
                    call stdlib_dcopy( m, a(1_ilp,1_ilp), 1_ilp, u(1_ilp,1_ilp), 1_ilp )
                 end if
              end if
              if ( rsvec ) then
                  v(1_ilp,1_ilp) = one
              end if
              if ( sva(1_ilp) < (big*scalem) ) then
                 sva(1_ilp)  = sva(1_ilp) / scalem
                 scalem  = one
              end if
              work(1_ilp) = one / scalem
              work(2_ilp) = one
              if ( sva(1_ilp) /= zero ) then
                 iwork(1_ilp) = 1_ilp
                 if ( ( sva(1_ilp) / scalem) >= sfmin ) then
                    iwork(2_ilp) = 1_ilp
                 else
                    iwork(2_ilp) = 0_ilp
                 end if
              else
                 iwork(1_ilp) = 0_ilp
                 iwork(2_ilp) = 0_ilp
              end if
              iwork(3_ilp) = 0_ilp
              if ( errest ) work(3_ilp) = one
              if ( lsvec .and. rsvec ) then
                 work(4_ilp) = one
                 work(5_ilp) = one
              end if
              if ( l2tran ) then
                 work(6_ilp) = zero
                 work(7_ilp) = zero
              end if
              return
           end if
           transp = .false.
           l2tran = l2tran .and. ( m == n )
           aatmax = -one
           aatmin =  big
           if ( rowpiv .or. l2tran ) then
           ! compute the row norms, needed to determine row pivoting sequence
           ! (in the case of heavily row weighted a, row pivoting is strongly
           ! advised) and to collect information needed to compare the
           ! structures of a * a^t and a^t * a (in the case l2tran==.true.).
              if ( l2tran ) then
                 do p = 1, m
                    xsc   = zero
                    temp1 = one
                    call stdlib_dlassq( n, a(p,1_ilp), lda, xsc, temp1 )
                    ! stdlib_dlassq gets both the ell_2 and the ell_infinity norm
                    ! in one pass through the vector
                    work(m+n+p)  = xsc * scalem
                    work(n+p)    = xsc * (scalem*sqrt(temp1))
                    aatmax = max( aatmax, work(n+p) )
                    if (work(n+p) /= zero) aatmin = min(aatmin,work(n+p))
                 end do
              else
                 do p = 1, m
                    work(m+n+p) = scalem*abs( a(p,stdlib_idamax(n,a(p,1_ilp),lda)) )
                    aatmax = max( aatmax, work(m+n+p) )
                    aatmin = min( aatmin, work(m+n+p) )
                 end do
              end if
           end if
           ! for square matrix a try to determine whether a^t  would be  better
           ! input for the preconditioned jacobi svd, with faster convergence.
           ! the decision is based on an o(n) function of the vector of column
           ! and row norms of a, based on the shannon entropy. this should give
           ! the right choice in most cases when the difference actually matters.
           ! it may fail and pick the slower converging side.
           entra  = zero
           entrat = zero
           if ( l2tran ) then
              xsc   = zero
              temp1 = one
              call stdlib_dlassq( n, sva, 1_ilp, xsc, temp1 )
              temp1 = one / temp1
              entra = zero
              do p = 1, n
                 big1  = ( ( sva(p) / xsc )**2_ilp ) * temp1
                 if ( big1 /= zero ) entra = entra + big1 * log(big1)
              end do
              entra = - entra / log(real(n,KIND=dp))
              ! now, sva().^2/trace(a^t * a) is a point in the probability simplex.
              ! it is derived from the diagonal of  a^t * a.  do the same with the
              ! diagonal of a * a^t, compute the entropy of the corresponding
              ! probability distribution. note that a * a^t and a^t * a have the
              ! same trace.
              entrat = zero
              do p = n+1, n+m
                 big1 = ( ( work(p) / xsc )**2_ilp ) * temp1
                 if ( big1 /= zero ) entrat = entrat + big1 * log(big1)
              end do
              entrat = - entrat / log(real(m,KIND=dp))
              ! analyze the entropies and decide a or a^t. smaller entropy
              ! usually means better input for the algorithm.
              transp = ( entrat < entra )
              ! if a^t is better than a, transpose a.
              if ( transp ) then
                 ! in an optimal implementation, this trivial transpose
                 ! should be replaced with faster transpose.
                 do p = 1, n - 1
                    do q = p + 1, n
                        temp1 = a(q,p)
                       a(q,p) = a(p,q)
                       a(p,q) = temp1
                    end do
                 end do
                 do p = 1, n
                    work(m+n+p) = sva(p)
                    sva(p)      = work(n+p)
                 end do
                 temp1  = aapp
                 aapp   = aatmax
                 aatmax = temp1
                 temp1  = aaqq
                 aaqq   = aatmin
                 aatmin = temp1
                 kill   = lsvec
                 lsvec  = rsvec
                 rsvec  = kill
                 if ( lsvec ) n1 = n
                 rowpiv = .true.
              end if
           end if
           ! end if l2tran
           ! scale the matrix so that its maximal singular value remains less
           ! than sqrt(big) -- the matrix is scaled so that its maximal column
           ! has euclidean norm equal to sqrt(big/n). the only reason to keep
           ! sqrt(big) instead of big is the fact that stdlib_dgejsv uses lapack and
           ! blas routines that, in some implementations, are not capable of
           ! working in the full interval [sfmin,big] and that they may provoke
           ! overflows in the intermediate results. if the singular values spread
           ! from sfmin to big, then stdlib_dgesvj will compute them. so, in that case,
           ! one should use stdlib_dgesvj instead of stdlib_dgejsv.
           big1   = sqrt( big )
           temp1  = sqrt( big / real(n,KIND=dp) )
           call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aapp, temp1, n, 1_ilp, sva, n, ierr )
           if ( aaqq > (aapp * sfmin) ) then
               aaqq = ( aaqq / aapp ) * temp1
           else
               aaqq = ( aaqq * temp1 ) / aapp
           end if
           temp1 = temp1 * scalem
           call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aapp, temp1, m, n, a, lda, ierr )
           ! to undo scaling at the end of this procedure, multiply the
           ! computed singular values with uscal2 / uscal1.
           uscal1 = temp1
           uscal2 = aapp
           if ( l2kill ) then
              ! l2kill enforces computation of nonzero singular values in
              ! the restricted range of condition number of the initial a,
              ! sigma_max(a) / sigma_min(a) approx. sqrt(big)/sqrt(sfmin).
              xsc = sqrt( sfmin )
           else
              xsc = small
              ! now, if the condition number of a is too big,
              ! sigma_max(a) / sigma_min(a) > sqrt(big/n) * epsln / sfmin,
              ! as a precaution measure, the full svd is computed using stdlib_dgesvj
              ! with accumulated jacobi rotations. this provides numerically
              ! more robust computation, at the cost of slightly increased run
              ! time. depending on the concrete implementation of blas and lapack
              ! (i.e. how they behave in presence of extreme ill-conditioning) the
              ! implementor may decide to remove this switch.
              if ( ( aaqq<sqrt(sfmin) ) .and. lsvec .and. rsvec ) then
                 jracc = .true.
              end if
           end if
           if ( aaqq < xsc ) then
              do p = 1, n
                 if ( sva(p) < xsc ) then
                    call stdlib_dlaset( 'A', m, 1_ilp, zero, zero, a(1_ilp,p), lda )
                    sva(p) = zero
                 end if
              end do
           end if
           ! preconditioning using qr factorization with pivoting
           if ( rowpiv ) then
              ! optional row permutation (bjoerck row pivoting):
              ! a result by cox and higham shows that the bjoerck's
              ! row pivoting combined with standard column pivoting
              ! has similar effect as powell-reid complete pivoting.
              ! the ell-infinity norms of a are made nonincreasing.
              do p = 1, m - 1
                 q = stdlib_idamax( m-p+1, work(m+n+p), 1_ilp ) + p - 1_ilp
                 iwork(2_ilp*n+p) = q
                 if ( p /= q ) then
                    temp1       = work(m+n+p)
                    work(m+n+p) = work(m+n+q)
                    work(m+n+q) = temp1
                 end if
              end do
              call stdlib_dlaswp( n, a, lda, 1_ilp, m-1, iwork(2_ilp*n+1), 1_ilp )
           end if
           ! end of the preparation phase (scaling, optional sorting and
           ! transposing, optional flushing of small columns).
           ! preconditioning
           ! if the full svd is needed, the right singular vectors are computed
           ! from a matrix equation, and for that we need theoretical analysis
           ! of the businger-golub pivoting. so we use stdlib_dgeqp3 as the first rr qrf.
           ! in all other cases the first rr qrf can be chosen by other criteria
           ! (eg speed by replacing global with restricted window pivoting, such
           ! as in sgeqpx from toms # 782). good results will be obtained using
           ! sgeqpx with properly (!) chosen numerical parameters.
           ! any improvement of stdlib_dgeqp3 improves overall performance of stdlib_dgejsv.
           ! a * p1 = q1 * [ r1^t 0]^t:
           do p = 1, n
              ! All Columns Are Free Columns
              iwork(p) = 0_ilp
           end do
           call stdlib_dgeqp3( m,n,a,lda, iwork,work, work(n+1),lwork-n, ierr )
           ! the upper triangular matrix r1 from the first qrf is inspected for
           ! rank deficiency and possibilities for deflation, or possible
           ! ill-conditioning. depending on the user specified flag l2rank,
           ! the procedure explores possibilities to reduce the numerical
           ! rank by inspecting the computed upper triangular factor. if
           ! l2rank or l2aber are up, then stdlib_dgejsv will compute the svd of
           ! a + da, where ||da|| <= f(m,n)*epsln.
           nr = 1_ilp
           if ( l2aber ) then
              ! standard absolute error bound suffices. all sigma_i with
              ! sigma_i < n*epsln*||a|| are flushed to zero. this is an
              ! aggressive enforcement of lower numerical rank by introducing a
              ! backward error of the order of n*epsln*||a||.
              temp1 = sqrt(real(n,KIND=dp))*epsln
              loop_3002: do p = 2, n
                 if ( abs(a(p,p)) >= (temp1*abs(a(1_ilp,1_ilp))) ) then
                    nr = nr + 1_ilp
                 else
                    exit loop_3002
                 end if
              end do loop_3002
           else if ( l2rank ) then
              ! .. similarly as above, only slightly more gentle (less aggressive).
              ! sudden drop on the diagonal of r1 is used as the criterion for
              ! close-to-rank-deficient.
              temp1 = sqrt(sfmin)
              loop_3402: do p = 2, n
                 if ( ( abs(a(p,p)) < (epsln*abs(a(p-1,p-1))) ) .or.( abs(a(p,p)) < small ) .or.( &
                           l2kill .and. (abs(a(p,p)) < temp1) ) ) exit loop_3402
                 nr = nr + 1_ilp
              end do loop_3402
           else
              ! the goal is high relative accuracy. however, if the matrix
              ! has high scaled condition number the relative accuracy is in
              ! general not feasible. later on, a condition number estimator
              ! will be deployed to estimate the scaled condition number.
              ! here we just remove the underflowed part of the triangular
              ! factor. this prevents the situation in which the code is
              ! working hard to get the accuracy not warranted by the data.
              temp1  = sqrt(sfmin)
              loop_3302: do p = 2, n
                 if ( ( abs(a(p,p)) < small ) .or.( l2kill .and. (abs(a(p,p)) < temp1) ) ) exit loop_3302
                 nr = nr + 1_ilp
              end do loop_3302              
           end if
           almort = .false.
           if ( nr == n ) then
              maxprj = one
              do p = 2, n
                 temp1  = abs(a(p,p)) / sva(iwork(p))
                 maxprj = min( maxprj, temp1 )
              end do
              if ( maxprj**2_ilp >= one - real(n,KIND=dp)*epsln ) almort = .true.
           end if
           sconda = - one
           condr1 = - one
           condr2 = - one
           if ( errest ) then
              if ( n == nr ) then
                 if ( rsvec ) then
                    ! V Is Available As Workspace
                    call stdlib_dlacpy( 'U', n, n, a, lda, v, ldv )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_dscal( p, one/temp1, v(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_dpocon( 'U', n, v, ldv, one, temp1,work(n+1), iwork(2_ilp*n+m+1), &
                              ierr )
                 else if ( lsvec ) then
                    ! U Is Available As Workspace
                    call stdlib_dlacpy( 'U', n, n, a, lda, u, ldu )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_dscal( p, one/temp1, u(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_dpocon( 'U', n, u, ldu, one, temp1,work(n+1), iwork(2_ilp*n+m+1), &
                              ierr )
                 else
                    call stdlib_dlacpy( 'U', n, n, a, lda, work(n+1), n )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_dscal( p, one/temp1, work(n+(p-1)*n+1), 1_ilp )
                    end do
                 ! The Columns Of R Are Scaled To Have Unit Euclidean Lengths
                    call stdlib_dpocon( 'U', n, work(n+1), n, one, temp1,work(n+n*n+1), iwork(2_ilp*n+&
                              m+1), ierr )
                 end if
                 sconda = one / sqrt(temp1)
                 ! sconda is an estimate of sqrt(||(r^t * r)^(-1)||_1).
                 ! n^(-1/4) * sconda <= ||r^(-1)||_2 <= n^(1/4) * sconda
              else
                 sconda = - one
              end if
           end if
           l2pert = l2pert .and. ( abs( a(1_ilp,1_ilp)/a(nr,nr) ) > sqrt(big1) )
           ! if there is no violent scaling, artificial perturbation is not needed.
           ! phase 3:
           if ( .not. ( rsvec .or. lsvec ) ) then
               ! singular values only
               ! .. transpose a(1:nr,1:n)
              do p = 1, min( n-1, nr )
                 call stdlib_dcopy( n-p, a(p,p+1), lda, a(p+1,p), 1_ilp )
              end do
              ! the following two do-loops introduce small relative perturbation
              ! into the strict upper triangle of the lower triangular matrix.
              ! small entries below the main diagonal are also changed.
              ! this modification is useful if the computing environment does not
              ! provide/allow flush to zero underflow, for it prevents many
              ! annoying denormalized numbers in case of strongly scaled matrices.
              ! the perturbation is structured so that it does not introduce any
              ! new perturbation of the singular values, and it does not destroy
              ! the job done by the preconditioner.
              ! the licence for this perturbation is in the variable l2pert, which
              ! should be .false. if flush to zero underflow is active.
              if ( .not. almort ) then
                 if ( l2pert ) then
                    ! xsc = sqrt(small)
                    xsc = epsln / real(n,KIND=dp)
                    do q = 1, nr
                       temp1 = xsc*abs(a(q,q))
                       do p = 1, n
                          if ( ( (p>q) .and. (abs(a(p,q))<=temp1) ).or. ( p < q ) )a(p,q) = sign( &
                                    temp1, a(p,q) )
                       end do
                    end do
                 else
                    call stdlib_dlaset( 'U', nr-1,nr-1, zero,zero, a(1_ilp,2_ilp),lda )
                 end if
                  ! Second Preconditioning Using The Qr Factorization
                 call stdlib_dgeqrf( n,nr, a,lda, work, work(n+1),lwork-n, ierr )
                 ! And Transpose Upper To Lower Triangular
                 do p = 1, nr - 1
                    call stdlib_dcopy( nr-p, a(p,p+1), lda, a(p+1,p), 1_ilp )
                 end do
              end if
                 ! row-cyclic jacobi svd algorithm with column pivoting
                 ! .. again some perturbation (a "background noise") is added
                 ! to drown denormals
                 if ( l2pert ) then
                    ! xsc = sqrt(small)
                    xsc = epsln / real(n,KIND=dp)
                    do q = 1, nr
                       temp1 = xsc*abs(a(q,q))
                       do p = 1, nr
                          if ( ( (p>q) .and. (abs(a(p,q))<=temp1) ).or. ( p < q ) )a(p,q) = sign( &
                                    temp1, a(p,q) )
                       end do
                    end do
                 else
                    call stdlib_dlaset( 'U', nr-1, nr-1, zero, zero, a(1_ilp,2_ilp), lda )
                 end if
                 ! .. and one-sided jacobi rotations are started on a lower
                 ! triangular matrix (plus perturbation which is ignored in
                 ! the part which destroys triangular form (confusing?!))
                 call stdlib_dgesvj( 'L', 'NOU', 'NOV', nr, nr, a, lda, sva,n, v, ldv, work, &
                           lwork, info )
                 scalem  = work(1_ilp)
                 numrank = nint(work(2_ilp),KIND=ilp)
           else if ( rsvec .and. ( .not. lsvec ) ) then
              ! -> singular values and right singular vectors <-
              if ( almort ) then
                 ! In This Case Nr Equals N
                 do p = 1, nr
                    call stdlib_dcopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                 end do
                 call stdlib_dlaset( 'UPPER', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
                 call stdlib_dgesvj( 'L','U','N', n, nr, v,ldv, sva, nr, a,lda,work, lwork, info )
                           
                 scalem  = work(1_ilp)
                 numrank = nint(work(2_ilp),KIND=ilp)
              else
              ! .. two more qr factorizations ( one qrf is not enough, two require
              ! accumulated product of jacobi rotations, three are perfect )
                 call stdlib_dlaset( 'LOWER', nr-1, nr-1, zero, zero, a(2_ilp,1_ilp), lda )
                 call stdlib_dgelqf( nr, n, a, lda, work, work(n+1), lwork-n, ierr)
                 call stdlib_dlacpy( 'LOWER', nr, nr, a, lda, v, ldv )
                 call stdlib_dlaset( 'UPPER', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
                 call stdlib_dgeqrf( nr, nr, v, ldv, work(n+1), work(2_ilp*n+1),lwork-2*n, ierr )
                           
                 do p = 1, nr
                    call stdlib_dcopy( nr-p+1, v(p,p), ldv, v(p,p), 1_ilp )
                 end do
                 call stdlib_dlaset( 'UPPER', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
                 call stdlib_dgesvj( 'LOWER', 'U','N', nr, nr, v,ldv, sva, nr, u,ldu, work(n+1), &
                           lwork, info )
                 scalem  = work(n+1)
                 numrank = nint(work(n+2),KIND=ilp)
                 if ( nr < n ) then
                    call stdlib_dlaset( 'A',n-nr, nr, zero,zero, v(nr+1,1_ilp),   ldv )
                    call stdlib_dlaset( 'A',nr, n-nr, zero,zero, v(1_ilp,nr+1),   ldv )
                    call stdlib_dlaset( 'A',n-nr,n-nr,zero,one, v(nr+1,nr+1), ldv )
                 end if
              call stdlib_dormlq( 'LEFT', 'TRANSPOSE', n, n, nr, a, lda, work,v, ldv, work(n+1), &
                        lwork-n, ierr )
              end if
              do p = 1, n
                 call stdlib_dcopy( n, v(p,1_ilp), ldv, a(iwork(p),1_ilp), lda )
              end do
              call stdlib_dlacpy( 'ALL', n, n, a, lda, v, ldv )
              if ( transp ) then
                 call stdlib_dlacpy( 'ALL', n, n, v, ldv, u, ldu )
              end if
           else if ( lsvec .and. ( .not. rsvec ) ) then
              ! Singular Values And Left Singular Vectors                 
              ! Second Preconditioning Step To Avoid Need To Accumulate
              ! jacobi rotations in the jacobi iterations.
              do p = 1, nr
                 call stdlib_dcopy( n-p+1, a(p,p), lda, u(p,p), 1_ilp )
              end do
              call stdlib_dlaset( 'UPPER', nr-1, nr-1, zero, zero, u(1_ilp,2_ilp), ldu )
              call stdlib_dgeqrf( n, nr, u, ldu, work(n+1), work(2_ilp*n+1),lwork-2*n, ierr )
              do p = 1, nr - 1
                 call stdlib_dcopy( nr-p, u(p,p+1), ldu, u(p+1,p), 1_ilp )
              end do
              call stdlib_dlaset( 'UPPER', nr-1, nr-1, zero, zero, u(1_ilp,2_ilp), ldu )
              call stdlib_dgesvj( 'LOWER', 'U', 'N', nr,nr, u, ldu, sva, nr, a,lda, work(n+1), &
                        lwork-n, info )
              scalem  = work(n+1)
              numrank = nint(work(n+2),KIND=ilp)
              if ( nr < m ) then
                 call stdlib_dlaset( 'A',  m-nr, nr,zero, zero, u(nr+1,1_ilp), ldu )
                 if ( nr < n1 ) then
                    call stdlib_dlaset( 'A',nr, n1-nr, zero, zero, u(1_ilp,nr+1), ldu )
                    call stdlib_dlaset( 'A',m-nr,n1-nr,zero,one,u(nr+1,nr+1), ldu )
                 end if
              end if
              call stdlib_dormqr( 'LEFT', 'NO TR', m, n1, n, a, lda, work, u,ldu, work(n+1), &
                        lwork-n, ierr )
              if ( rowpiv )call stdlib_dlaswp( n1, u, ldu, 1_ilp, m-1, iwork(2_ilp*n+1), -1_ilp )
              do p = 1, n1
                 xsc = one / stdlib_dnrm2( m, u(1_ilp,p), 1_ilp )
                 call stdlib_dscal( m, xsc, u(1_ilp,p), 1_ilp )
              end do
              if ( transp ) then
                 call stdlib_dlacpy( 'ALL', n, n, u, ldu, v, ldv )
              end if
           else
              ! Full Svd 
              if ( .not. jracc ) then
              if ( .not. almort ) then
                 ! second preconditioning step (qrf [with pivoting])
                 ! note that the composition of transpose, qrf and transpose is
                 ! equivalent to an lqf call. since in many libraries the qrf
                 ! seems to be better optimized than the lqf, we do explicit
                 ! transpose and use the qrf. this is subject to changes in an
                 ! optimized implementation of stdlib_dgejsv.
                 do p = 1, nr
                    call stdlib_dcopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                 end do
                 ! The Following Two Loops Perturb Small Entries To Avoid
                 ! denormals in the second qr factorization, where they are
                 ! as good as zeros. this is done to avoid painfully slow
                 ! computation with denormals. the relative size of the perturbation
                 ! is a parameter that can be changed by the implementer.
                 ! this perturbation device will be obsolete on machines with
                 ! properly implemented arithmetic.
                 ! to switch it off, set l2pert=.false. to remove it from  the
                 ! code, remove the action under l2pert=.true., leave the else part.
                 ! the following two loops should be blocked and fused with the
                 ! transposed copy above.
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do q = 1, nr
                       temp1 = xsc*abs( v(q,q) )
                       do p = 1, n
                          if ( ( p > q ) .and. ( abs(v(p,q)) <= temp1 ).or. ( p < q ) )v(p,q) = &
                                    sign( temp1, v(p,q) )
                          if ( p < q ) v(p,q) = - v(p,q)
                       end do
                    end do
                 else
                    call stdlib_dlaset( 'U', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
                 end if
                 ! estimate the row scaled condition number of r1
                 ! (if r1 is rectangular, n > nr, then the condition number
                 ! of the leading nr x nr submatrix is estimated.)
                 call stdlib_dlacpy( 'L', nr, nr, v, ldv, work(2_ilp*n+1), nr )
                 do p = 1, nr
                    temp1 = stdlib_dnrm2(nr-p+1,work(2_ilp*n+(p-1)*nr+p),1_ilp)
                    call stdlib_dscal(nr-p+1,one/temp1,work(2_ilp*n+(p-1)*nr+p),1_ilp)
                 end do
                 call stdlib_dpocon('LOWER',nr,work(2_ilp*n+1),nr,one,temp1,work(2_ilp*n+nr*nr+1),iwork(m+&
                           2_ilp*n+1),ierr)
                 condr1 = one / sqrt(temp1)
                 ! Here Need A Second Opinion On The Condition Number
                 ! Then Assume Worst Case Scenario
                 ! r1 is ok for inverse <=> condr1 < real(n,KIND=dp)
                 ! more conservative    <=> condr1 < sqrt(real(n,KIND=dp))
                 cond_ok = sqrt(real(nr,KIND=dp))
      ! [tp]       cond_ok is a tuning parameter.
                 if ( condr1 < cond_ok ) then
                    ! .. the second qrf without pivoting. note: in an optimized
                    ! implementation, this qrf should be implemented as the qrf
                    ! of a lower triangular matrix.
                    ! r1^t = q2 * r2
                    call stdlib_dgeqrf( n, nr, v, ldv, work(n+1), work(2_ilp*n+1),lwork-2*n, ierr )
                              
                    if ( l2pert ) then
                       xsc = sqrt(small)/epsln
                       do p = 2, nr
                          do q = 1, p - 1
                             temp1 = xsc * min(abs(v(p,p)),abs(v(q,q)))
                             if ( abs(v(q,p)) <= temp1 )v(q,p) = sign( temp1, v(q,p) )
                          end do
                       end do
                    end if
                    if ( nr /= n )call stdlib_dlacpy( 'A', n, nr, v, ldv, work(2_ilp*n+1), n )
                    ! .. save ...
                 ! This Transposed Copy Should Be Better Than Naive
                    do p = 1, nr - 1
                       call stdlib_dcopy( nr-p, v(p,p+1), ldv, v(p+1,p), 1_ilp )
                    end do
                    condr2 = condr1
                 else
                    ! .. ill-conditioned case: second qrf with pivoting
                    ! note that windowed pivoting would be equally good
                    ! numerically, and more run-time efficient. so, in
                    ! an optimal implementation, the next call to stdlib_dgeqp3
                    ! should be replaced with eg. call sgeqpx (acm toms #782)
                    ! with properly (carefully) chosen parameters.
                    ! r1^t * p2 = q2 * r2
                    do p = 1, nr
                       iwork(n+p) = 0_ilp
                    end do
                    call stdlib_dgeqp3( n, nr, v, ldv, iwork(n+1), work(n+1),work(2_ilp*n+1), lwork-&
                              2_ilp*n, ierr )
      ! *               call stdlib_dgeqrf( n, nr, v, ldv, work(n+1), work(2*n+1),
      ! *     $              lwork-2*n, ierr )
                    if ( l2pert ) then
                       xsc = sqrt(small)
                       do p = 2, nr
                          do q = 1, p - 1
                             temp1 = xsc * min(abs(v(p,p)),abs(v(q,q)))
                             if ( abs(v(q,p)) <= temp1 )v(q,p) = sign( temp1, v(q,p) )
                          end do
                       end do
                    end if
                    call stdlib_dlacpy( 'A', n, nr, v, ldv, work(2_ilp*n+1), n )
                    if ( l2pert ) then
                       xsc = sqrt(small)
                       do p = 2, nr
                          do q = 1, p - 1
                             temp1 = xsc * min(abs(v(p,p)),abs(v(q,q)))
                             v(p,q) = - sign( temp1, v(q,p) )
                          end do
                       end do
                    else
                       call stdlib_dlaset( 'L',nr-1,nr-1,zero,zero,v(2_ilp,1_ilp),ldv )
                    end if
                    ! now, compute r2 = l3 * q3, the lq factorization.
                    call stdlib_dgelqf( nr, nr, v, ldv, work(2_ilp*n+n*nr+1),work(2_ilp*n+n*nr+nr+1), &
                              lwork-2*n-n*nr-nr, ierr )
                    ! And Estimate The Condition Number
                    call stdlib_dlacpy( 'L',nr,nr,v,ldv,work(2_ilp*n+n*nr+nr+1),nr )
                    do p = 1, nr
                       temp1 = stdlib_dnrm2( p, work(2_ilp*n+n*nr+nr+p), nr )
                       call stdlib_dscal( p, one/temp1, work(2_ilp*n+n*nr+nr+p), nr )
                    end do
                    call stdlib_dpocon( 'L',nr,work(2_ilp*n+n*nr+nr+1),nr,one,temp1,work(2_ilp*n+n*nr+nr+&
                              nr*nr+1),iwork(m+2*n+1),ierr )
                    condr2 = one / sqrt(temp1)
                    if ( condr2 >= cond_ok ) then
                       ! Save The Householder Vectors Used For Q3
                       ! (this overwrites the copy of r2, as it will not be
                       ! needed in this branch, but it does not overwritte the
                       ! huseholder vectors of q2.).
                       call stdlib_dlacpy( 'U', nr, nr, v, ldv, work(2_ilp*n+1), n )
                       ! And The Rest Of The Information On Q3 Is In
                       ! work(2*n+n*nr+1:2*n+n*nr+n)
                    end if
                 end if
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do q = 2, nr
                       temp1 = xsc * v(q,q)
                       do p = 1, q - 1
                          ! v(p,q) = - sign( temp1, v(q,p) )
                          v(p,q) = - sign( temp1, v(p,q) )
                       end do
                    end do
                 else
                    call stdlib_dlaset( 'U', nr-1,nr-1, zero,zero, v(1_ilp,2_ilp), ldv )
                 end if
              ! second preconditioning finished; continue with jacobi svd
              ! the input matrix is lower trinagular.
              ! recover the right singular vectors as solution of a well
              ! conditioned triangular matrix equation.
                 if ( condr1 < cond_ok ) then
                    call stdlib_dgesvj( 'L','U','N',nr,nr,v,ldv,sva,nr,u,ldu,work(2_ilp*n+n*nr+nr+1),&
                              lwork-2*n-n*nr-nr,info )
                    scalem  = work(2_ilp*n+n*nr+nr+1)
                    numrank = nint(work(2_ilp*n+n*nr+nr+2),KIND=ilp)
                    do p = 1, nr
                       call stdlib_dcopy( nr, v(1_ilp,p), 1_ilp, u(1_ilp,p), 1_ilp )
                       call stdlib_dscal( nr, sva(p),    v(1_ilp,p), 1_ilp )
                    end do
              ! Pick The Right Matrix Equation And Solve It
                    if ( nr == n ) then
       ! :))             .. best case, r1 is inverted. the solution of this matrix
                       ! equation is q2*v2 = the product of the jacobi rotations
                       ! used in stdlib_dgesvj, premultiplied with the orthogonal matrix
                       ! from the second qr factorization.
                       call stdlib_dtrsm( 'L','U','N','N', nr,nr,one, a,lda, v,ldv )
                    else
                       ! .. r1 is well conditioned, but non-square. transpose(r2)
                       ! is inverted to get the product of the jacobi rotations
                       ! used in stdlib_dgesvj. the q-factor from the second qr
                       ! factorization is then built in explicitly.
                       call stdlib_dtrsm('L','U','T','N',nr,nr,one,work(2_ilp*n+1),n,v,ldv)
                       if ( nr < n ) then
                         call stdlib_dlaset('A',n-nr,nr,zero,zero,v(nr+1,1_ilp),ldv)
                         call stdlib_dlaset('A',nr,n-nr,zero,zero,v(1_ilp,nr+1),ldv)
                         call stdlib_dlaset('A',n-nr,n-nr,zero,one,v(nr+1,nr+1),ldv)
                       end if
                       call stdlib_dormqr('L','N',n,n,nr,work(2_ilp*n+1),n,work(n+1),v,ldv,work(2_ilp*n+&
                                 n*nr+nr+1),lwork-2*n-n*nr-nr,ierr)
                    end if
                 else if ( condr2 < cond_ok ) then
       ! :)           .. the input matrix a is very likely a relative of
                    ! the kahan matrix :)
                    ! the matrix r2 is inverted. the solution of the matrix equation
                    ! is q3^t*v3 = the product of the jacobi rotations (appplied to
                    ! the lower triangular l3 from the lq factorization of
                    ! r2=l3*q3), pre-multiplied with the transposed q3.
                    call stdlib_dgesvj( 'L', 'U', 'N', nr, nr, v, ldv, sva, nr, u,ldu, work(2_ilp*n+&
                              n*nr+nr+1), lwork-2*n-n*nr-nr, info )
                    scalem  = work(2_ilp*n+n*nr+nr+1)
                    numrank = nint(work(2_ilp*n+n*nr+nr+2),KIND=ilp)
                    do p = 1, nr
                       call stdlib_dcopy( nr, v(1_ilp,p), 1_ilp, u(1_ilp,p), 1_ilp )
                       call stdlib_dscal( nr, sva(p),    u(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_dtrsm('L','U','N','N',nr,nr,one,work(2_ilp*n+1),n,u,ldu)
                    ! Apply The Permutation From The Second Qr Factorization
                    do q = 1, nr
                       do p = 1, nr
                          work(2_ilp*n+n*nr+nr+iwork(n+p)) = u(p,q)
                       end do
                       do p = 1, nr
                          u(p,q) = work(2_ilp*n+n*nr+nr+p)
                       end do
                    end do
                    if ( nr < n ) then
                       call stdlib_dlaset( 'A',n-nr,nr,zero,zero,v(nr+1,1_ilp),ldv )
                       call stdlib_dlaset( 'A',nr,n-nr,zero,zero,v(1_ilp,nr+1),ldv )
                       call stdlib_dlaset( 'A',n-nr,n-nr,zero,one,v(nr+1,nr+1),ldv )
                    end if
                    call stdlib_dormqr( 'L','N',n,n,nr,work(2_ilp*n+1),n,work(n+1),v,ldv,work(2_ilp*n+&
                              n*nr+nr+1),lwork-2*n-n*nr-nr,ierr )
                 else
                    ! last line of defense.
       ! #:(          this is a rather pathological case: no scaled condition
                    ! improvement after two pivoted qr factorizations. other
                    ! possibility is that the rank revealing qr factorization
                    ! or the condition estimator has failed, or the cond_ok
                    ! is set very close to one (which is unnecessary). normally,
                    ! this branch should never be executed, but in rare cases of
                    ! failure of the rrqr or condition estimator, the last line of
                    ! defense ensures that stdlib_dgejsv completes the task.
                    ! compute the full svd of l3 using stdlib_dgesvj with explicit
                    ! accumulation of jacobi rotations.
                    call stdlib_dgesvj( 'L', 'U', 'V', nr, nr, v, ldv, sva, nr, u,ldu, work(2_ilp*n+&
                              n*nr+nr+1), lwork-2*n-n*nr-nr, info )
                    scalem  = work(2_ilp*n+n*nr+nr+1)
                    numrank = nint(work(2_ilp*n+n*nr+nr+2),KIND=ilp)
                    if ( nr < n ) then
                       call stdlib_dlaset( 'A',n-nr,nr,zero,zero,v(nr+1,1_ilp),ldv )
                       call stdlib_dlaset( 'A',nr,n-nr,zero,zero,v(1_ilp,nr+1),ldv )
                       call stdlib_dlaset( 'A',n-nr,n-nr,zero,one,v(nr+1,nr+1),ldv )
                    end if
                    call stdlib_dormqr( 'L','N',n,n,nr,work(2_ilp*n+1),n,work(n+1),v,ldv,work(2_ilp*n+&
                              n*nr+nr+1),lwork-2*n-n*nr-nr,ierr )
                    call stdlib_dormlq( 'L', 'T', nr, nr, nr, work(2_ilp*n+1), n,work(2_ilp*n+n*nr+1), u, &
                              ldu, work(2_ilp*n+n*nr+nr+1),lwork-2*n-n*nr-nr, ierr )
                    do q = 1, nr
                       do p = 1, nr
                          work(2_ilp*n+n*nr+nr+iwork(n+p)) = u(p,q)
                       end do
                       do p = 1, nr
                          u(p,q) = work(2_ilp*n+n*nr+nr+p)
                       end do
                    end do
                 end if
                 ! permute the rows of v using the (column) permutation from the
                 ! first qrf. also, scale the columns to make them unit in
                 ! euclidean norm. this applies to all cases.
                 temp1 = sqrt(real(n,KIND=dp)) * epsln
                 do q = 1, n
                    do p = 1, n
                       work(2_ilp*n+n*nr+nr+iwork(p)) = v(p,q)
                    end do
                    do p = 1, n
                       v(p,q) = work(2_ilp*n+n*nr+nr+p)
                    end do
                    xsc = one / stdlib_dnrm2( n, v(1_ilp,q), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_dscal( n, xsc, &
                              v(1_ilp,q), 1_ilp )
                 end do
                 ! at this moment, v contains the right singular vectors of a.
                 ! next, assemble the left singular vector matrix u (m x n).
                 if ( nr < m ) then
                    call stdlib_dlaset( 'A', m-nr, nr, zero, zero, u(nr+1,1_ilp), ldu )
                    if ( nr < n1 ) then
                       call stdlib_dlaset('A',nr,n1-nr,zero,zero,u(1_ilp,nr+1),ldu)
                       call stdlib_dlaset('A',m-nr,n1-nr,zero,one,u(nr+1,nr+1),ldu)
                    end if
                 end if
                 ! the q matrix from the first qrf is built into the left singular
                 ! matrix u. this applies to all cases.
                 call stdlib_dormqr( 'LEFT', 'NO_TR', m, n1, n, a, lda, work, u,ldu, work(n+1), &
                           lwork-n, ierr )
                 ! the columns of u are normalized. the cost is o(m*n) flops.
                 temp1 = sqrt(real(m,KIND=dp)) * epsln
                 do p = 1, nr
                    xsc = one / stdlib_dnrm2( m, u(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_dscal( m, xsc, &
                              u(1_ilp,p), 1_ilp )
                 end do
                 ! if the initial qrf is computed with row pivoting, the left
                 ! singular vectors must be adjusted.
                 if ( rowpiv )call stdlib_dlaswp( n1, u, ldu, 1_ilp, m-1, iwork(2_ilp*n+1), -1_ilp )
              else
              ! The Initial Matrix A Has Almost Orthogonal Columns And
              ! the second qrf is not needed
                 call stdlib_dlacpy( 'UPPER', n, n, a, lda, work(n+1), n )
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do p = 2, n
                       temp1 = xsc * work( n + (p-1)*n + p )
                       do q = 1, p - 1
                          work(n+(q-1)*n+p)=-sign(temp1,work(n+(p-1)*n+q))
                       end do
                    end do
                 else
                    call stdlib_dlaset( 'LOWER',n-1,n-1,zero,zero,work(n+2),n )
                 end if
                 call stdlib_dgesvj( 'UPPER', 'U', 'N', n, n, work(n+1), n, sva,n, u, ldu, work(n+&
                           n*n+1), lwork-n-n*n, info )
                 scalem  = work(n+n*n+1)
                 numrank = nint(work(n+n*n+2),KIND=ilp)
                 do p = 1, n
                    call stdlib_dcopy( n, work(n+(p-1)*n+1), 1_ilp, u(1_ilp,p), 1_ilp )
                    call stdlib_dscal( n, sva(p), work(n+(p-1)*n+1), 1_ilp )
                 end do
                 call stdlib_dtrsm( 'LEFT', 'UPPER', 'NOTRANS', 'NO UD', n, n,one, a, lda, work(n+&
                           1_ilp), n )
                 do p = 1, n
                    call stdlib_dcopy( n, work(n+p), n, v(iwork(p),1_ilp), ldv )
                 end do
                 temp1 = sqrt(real(n,KIND=dp))*epsln
                 do p = 1, n
                    xsc = one / stdlib_dnrm2( n, v(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_dscal( n, xsc, &
                              v(1_ilp,p), 1_ilp )
                 end do
                 ! assemble the left singular vector matrix u (m x n).
                 if ( n < m ) then
                    call stdlib_dlaset( 'A',  m-n, n, zero, zero, u(n+1,1_ilp), ldu )
                    if ( n < n1 ) then
                       call stdlib_dlaset( 'A',n,  n1-n, zero, zero,  u(1_ilp,n+1),ldu )
                       call stdlib_dlaset( 'A',m-n,n1-n, zero, one,u(n+1,n+1),ldu )
                    end if
                 end if
                 call stdlib_dormqr( 'LEFT', 'NO TR', m, n1, n, a, lda, work, u,ldu, work(n+1), &
                           lwork-n, ierr )
                 temp1 = sqrt(real(m,KIND=dp))*epsln
                 do p = 1, n1
                    xsc = one / stdlib_dnrm2( m, u(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_dscal( m, xsc, &
                              u(1_ilp,p), 1_ilp )
                 end do
                 if ( rowpiv )call stdlib_dlaswp( n1, u, ldu, 1_ilp, m-1, iwork(2_ilp*n+1), -1_ilp )
              end if
              ! end of the  >> almost orthogonal case <<  in the full svd
              else
              ! this branch deploys a preconditioned jacobi svd with explicitly
              ! accumulated rotations. it is included as optional, mainly for
              ! experimental purposes. it does perform well, and can also be used.
              ! in this implementation, this branch will be automatically activated
              ! if the  condition number sigma_max(a) / sigma_min(a) is predicted
              ! to be greater than the overflow threshold. this is because the
              ! a posteriori computation of the singular vectors assumes robust
              ! implementation of blas and some lapack procedures, capable of working
              ! in presence of extreme values. since that is not always the case, ...
              do p = 1, nr
                 call stdlib_dcopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
              end do
              if ( l2pert ) then
                 xsc = sqrt(small/epsln)
                 do q = 1, nr
                    temp1 = xsc*abs( v(q,q) )
                    do p = 1, n
                       if ( ( p > q ) .and. ( abs(v(p,q)) <= temp1 ).or. ( p < q ) )v(p,q) = sign(&
                                  temp1, v(p,q) )
                       if ( p < q ) v(p,q) = - v(p,q)
                    end do
                 end do
              else
                 call stdlib_dlaset( 'U', nr-1, nr-1, zero, zero, v(1_ilp,2_ilp), ldv )
              end if
              call stdlib_dgeqrf( n, nr, v, ldv, work(n+1), work(2_ilp*n+1),lwork-2*n, ierr )
              call stdlib_dlacpy( 'L', n, nr, v, ldv, work(2_ilp*n+1), n )
              do p = 1, nr
                 call stdlib_dcopy( nr-p+1, v(p,p), ldv, u(p,p), 1_ilp )
              end do
              if ( l2pert ) then
                 xsc = sqrt(small/epsln)
                 do q = 2, nr
                    do p = 1, q - 1
                       temp1 = xsc * min(abs(u(p,p)),abs(u(q,q)))
                       u(p,q) = - sign( temp1, u(q,p) )
                    end do
                 end do
              else
                 call stdlib_dlaset('U', nr-1, nr-1, zero, zero, u(1_ilp,2_ilp), ldu )
              end if
              call stdlib_dgesvj( 'G', 'U', 'V', nr, nr, u, ldu, sva,n, v, ldv, work(2_ilp*n+n*nr+1), &
                        lwork-2*n-n*nr, info )
              scalem  = work(2_ilp*n+n*nr+1)
              numrank = nint(work(2_ilp*n+n*nr+2),KIND=ilp)
              if ( nr < n ) then
                 call stdlib_dlaset( 'A',n-nr,nr,zero,zero,v(nr+1,1_ilp),ldv )
                 call stdlib_dlaset( 'A',nr,n-nr,zero,zero,v(1_ilp,nr+1),ldv )
                 call stdlib_dlaset( 'A',n-nr,n-nr,zero,one,v(nr+1,nr+1),ldv )
              end if
              call stdlib_dormqr( 'L','N',n,n,nr,work(2_ilp*n+1),n,work(n+1),v,ldv,work(2_ilp*n+n*nr+nr+1)&
                        ,lwork-2*n-n*nr-nr,ierr )
                 ! permute the rows of v using the (column) permutation from the
                 ! first qrf. also, scale the columns to make them unit in
                 ! euclidean norm. this applies to all cases.
                 temp1 = sqrt(real(n,KIND=dp)) * epsln
                 do q = 1, n
                    do p = 1, n
                       work(2_ilp*n+n*nr+nr+iwork(p)) = v(p,q)
                    end do
                    do p = 1, n
                       v(p,q) = work(2_ilp*n+n*nr+nr+p)
                    end do
                    xsc = one / stdlib_dnrm2( n, v(1_ilp,q), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_dscal( n, xsc, &
                              v(1_ilp,q), 1_ilp )
                 end do
                 ! at this moment, v contains the right singular vectors of a.
                 ! next, assemble the left singular vector matrix u (m x n).
              if ( nr < m ) then
                 call stdlib_dlaset( 'A',  m-nr, nr, zero, zero, u(nr+1,1_ilp), ldu )
                 if ( nr < n1 ) then
                    call stdlib_dlaset( 'A',nr,  n1-nr, zero, zero,  u(1_ilp,nr+1),ldu )
                    call stdlib_dlaset( 'A',m-nr,n1-nr, zero, one,u(nr+1,nr+1),ldu )
                 end if
              end if
              call stdlib_dormqr( 'LEFT', 'NO TR', m, n1, n, a, lda, work, u,ldu, work(n+1), &
                        lwork-n, ierr )
                 if ( rowpiv )call stdlib_dlaswp( n1, u, ldu, 1_ilp, m-1, iwork(2_ilp*n+1), -1_ilp )
              end if
              if ( transp ) then
                 ! .. swap u and v because the procedure worked on a^t
                 do p = 1, n
                    call stdlib_dswap( n, u(1_ilp,p), 1_ilp, v(1_ilp,p), 1_ilp )
                 end do
              end if
           end if
           ! end of the full svd
           ! undo scaling, if necessary (and possible)
           if ( uscal2 <= (big/sva(1_ilp))*uscal1 ) then
              call stdlib_dlascl( 'G', 0_ilp, 0_ilp, uscal1, uscal2, nr, 1_ilp, sva, n, ierr )
              uscal1 = one
              uscal2 = one
           end if
           if ( nr < n ) then
              do p = nr+1, n
                 sva(p) = zero
              end do
           end if
           work(1_ilp) = uscal2 * scalem
           work(2_ilp) = uscal1
           if ( errest ) work(3_ilp) = sconda
           if ( lsvec .and. rsvec ) then
              work(4_ilp) = condr1
              work(5_ilp) = condr2
           end if
           if ( l2tran ) then
              work(6_ilp) = entra
              work(7_ilp) = entrat
           end if
           iwork(1_ilp) = nr
           iwork(2_ilp) = numrank
           iwork(3_ilp) = warning
           return
     end subroutine stdlib_dgejsv


     pure module subroutine stdlib_cgejsv( joba, jobu, jobv, jobr, jobt, jobp,m, n, a, lda, sva, u, ldu, &
     !! CGEJSV computes the singular value decomposition (SVD) of a complex M-by-N
     !! matrix [A], where M >= N. The SVD of [A] is written as
     !! [A] = [U] * [SIGMA] * [V]^*,
     !! where [SIGMA] is an N-by-N (M-by-N) matrix which is zero except for its N
     !! diagonal elements, [U] is an M-by-N (or M-by-M) unitary matrix, and
     !! [V] is an N-by-N unitary matrix. The diagonal elements of [SIGMA] are
     !! the singular values of [A]. The columns of [U] and [V] are the left and
     !! the right singular vectors of [A], respectively. The matrices [U] and [V]
     !! are computed and stored in the arrays U and V, respectively. The diagonal
     !! of [SIGMA] is computed and stored in the array SVA.
               v, ldv,cwork, lwork, rwork, lrwork, iwork, info )
        ! -- lapack computational routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_sp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldu, ldv, lwork, lrwork, m, n
           ! Array Arguments 
           complex(sp), intent(inout) :: a(lda,*)
           complex(sp), intent(out) :: u(ldu,*), v(ldv,*), cwork(lwork)
           real(sp), intent(out) :: sva(n), rwork(lrwork)
           integer(ilp), intent(out) :: iwork(*)
           character, intent(in) :: joba, jobp, jobr, jobt, jobu, jobv
        ! ===========================================================================
           
           
           ! Local Scalars 
           complex(sp) :: ctemp
           real(sp) :: aapp, aaqq, aatmax, aatmin, big, big1, cond_ok, condr1, condr2, entra, &
                     entrat, epsln, maxprj, scalem, sconda, sfmin, small, temp1, uscal1, uscal2, xsc
           integer(ilp) :: ierr, n1, nr, numrank, p, q, warning
           logical(lk) :: almort, defr, errest, goscal, jracc, kill, lquery, lsvec, l2aber, &
                     l2kill, l2pert, l2rank, l2tran, noscal, rowpiv, rsvec, transp
           integer(ilp) :: optwrk, minwrk, minrwrk, miniwrk
           integer(ilp) :: lwcon, lwlqf, lwqp3, lwqrf, lwunmlq, lwunmqr, lwunmqrm, lwsvdj, &
                     lwsvdjv, lrwqp3, lrwcon, lrwsvdj, iwoff
           integer(ilp) :: lwrk_cgelqf, lwrk_cgeqp3, lwrk_cgeqp3n, lwrk_cgeqrf, lwrk_cgesvj, &
                     lwrk_cgesvjv, lwrk_cgesvju, lwrk_cunmlq, lwrk_cunmqr, lwrk_cunmqrm
           ! Local Arrays
           complex(sp) :: cdummy(1_ilp)
           real(sp) :: rdummy(1_ilp)
           ! Intrinsic Functions 
           ! test the input arguments
           lsvec  = stdlib_lsame( jobu, 'U' ) .or. stdlib_lsame( jobu, 'F' )
           jracc  = stdlib_lsame( jobv, 'J' )
           rsvec  = stdlib_lsame( jobv, 'V' ) .or. jracc
           rowpiv = stdlib_lsame( joba, 'F' ) .or. stdlib_lsame( joba, 'G' )
           l2rank = stdlib_lsame( joba, 'R' )
           l2aber = stdlib_lsame( joba, 'A' )
           errest = stdlib_lsame( joba, 'E' ) .or. stdlib_lsame( joba, 'G' )
           l2tran = stdlib_lsame( jobt, 'T' ) .and. ( m == n )
           l2kill = stdlib_lsame( jobr, 'R' )
           defr   = stdlib_lsame( jobr, 'N' )
           l2pert = stdlib_lsame( jobp, 'P' )
           lquery = ( lwork == -1_ilp ) .or. ( lrwork == -1_ilp )
           if ( .not.(rowpiv .or. l2rank .or. l2aber .or.errest .or. stdlib_lsame( joba, 'C' ) )) &
                     then
              info = - 1_ilp
           else if ( .not.( lsvec .or. stdlib_lsame( jobu, 'N' ) .or.( stdlib_lsame( jobu, 'W' ) &
                     .and. rsvec .and. l2tran ) ) ) then
              info = - 2_ilp
           else if ( .not.( rsvec .or. stdlib_lsame( jobv, 'N' ) .or.( stdlib_lsame( jobv, 'W' ) &
                     .and. lsvec .and. l2tran ) ) ) then
              info = - 3_ilp
           else if ( .not. ( l2kill .or. defr ) )    then
              info = - 4_ilp
           else if ( .not. ( stdlib_lsame(jobt,'T') .or. stdlib_lsame(jobt,'N') ) ) then
              info = - 5_ilp
           else if ( .not. ( l2pert .or. stdlib_lsame( jobp, 'N' ) ) ) then
              info = - 6_ilp
           else if ( m < 0_ilp ) then
              info = - 7_ilp
           else if ( ( n < 0_ilp ) .or. ( n > m ) ) then
              info = - 8_ilp
           else if ( lda < m ) then
              info = - 10_ilp
           else if ( lsvec .and. ( ldu < m ) ) then
              info = - 13_ilp
           else if ( rsvec .and. ( ldv < n ) ) then
              info = - 15_ilp
           else
              ! #:)
              info = 0_ilp
           end if
           if ( info == 0_ilp ) then
               ! Compute The Minimal And The Optimal Workspace Lengths
               ! [[the expressions for computing the minimal and the optimal
               ! values of lcwork, lrwork are written with a lot of redundancy and
               ! can be simplified. however, this verbose form is useful for
               ! maintenance and modifications of the code.]]
              ! .. minimal workspace length for stdlib_cgeqp3 of an m x n matrix,
               ! stdlib_cgeqrf of an n x n matrix, stdlib_cgelqf of an n x n matrix,
               ! stdlib_cunmlq for computing n x n matrix, stdlib_cunmqr for computing n x n
               ! matrix, stdlib_cunmqr for computing m x n matrix, respectively.
               lwqp3 = n+1
               lwqrf = max( 1_ilp, n )
               lwlqf = max( 1_ilp, n )
               lwunmlq  = max( 1_ilp, n )
               lwunmqr  = max( 1_ilp, n )
               lwunmqrm = max( 1_ilp, m )
              ! Minimal Workspace Length For Stdlib_Cpocon Of An N X N Matrix
               lwcon = 2_ilp * n
              ! .. minimal workspace length for stdlib_cgesvj of an n x n matrix,
               ! without and with explicit accumulation of jacobi rotations
               lwsvdj  = max( 2_ilp * n, 1_ilp )
               lwsvdjv = max( 2_ilp * n, 1_ilp )
               ! .. minimal real workspace length for stdlib_cgeqp3, stdlib_cpocon, stdlib_cgesvj
               lrwqp3  = 2_ilp * n
               lrwcon  = n
               lrwsvdj = n
               if ( lquery ) then
                   call stdlib_cgeqp3( m, n, a, lda, iwork, cdummy, cdummy, -1_ilp,rdummy, ierr )
                             
                   lwrk_cgeqp3 = real( cdummy(1_ilp),KIND=sp)
                   call stdlib_cgeqrf( n, n, a, lda, cdummy, cdummy,-1_ilp, ierr )
                   lwrk_cgeqrf = real( cdummy(1_ilp),KIND=sp)
                   call stdlib_cgelqf( n, n, a, lda, cdummy, cdummy,-1_ilp, ierr )
                   lwrk_cgelqf = real( cdummy(1_ilp),KIND=sp)
               end if
               minwrk  = 2_ilp
               optwrk  = 2_ilp
               miniwrk = n
               if ( .not. (lsvec .or. rsvec ) ) then
                   ! Minimal And Optimal Sizes Of The Complex Workspace If
                   ! only the singular values are requested
                   if ( errest ) then
                       minwrk = max( n+lwqp3, n**2_ilp+lwcon, n+lwqrf, lwsvdj )
                   else
                       minwrk = max( n+lwqp3, n+lwqrf, lwsvdj )
                   end if
                   if ( lquery ) then
                       call stdlib_cgesvj( 'L', 'N', 'N', n, n, a, lda, sva, n, v,ldv, cdummy, -1_ilp,&
                                  rdummy, -1_ilp, ierr )
                       lwrk_cgesvj = real( cdummy(1_ilp),KIND=sp)
                       if ( errest ) then
                           optwrk = max( n+lwrk_cgeqp3, n**2_ilp+lwcon,n+lwrk_cgeqrf, lwrk_cgesvj )
                                     
                       else
                           optwrk = max( n+lwrk_cgeqp3, n+lwrk_cgeqrf,lwrk_cgesvj )
                       end if
                   end if
                   if ( l2tran .or. rowpiv ) then
                       if ( errest ) then
                          minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwcon, lrwsvdj )
                       else
                          minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj )
                       end if
                   else
                       if ( errest ) then
                          minrwrk = max( 7_ilp, lrwqp3, lrwcon, lrwsvdj )
                       else
                          minrwrk = max( 7_ilp, lrwqp3, lrwsvdj )
                       end if
                   end if
                   if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
               else if ( rsvec .and. (.not.lsvec) ) then
                  ! Minimal And Optimal Sizes Of The Complex Workspace If The
                  ! singular values and the right singular vectors are requested
                  if ( errest ) then
                      minwrk = max( n+lwqp3, lwcon, lwsvdj, n+lwlqf,2_ilp*n+lwqrf, n+lwsvdj, n+&
                                lwunmlq )
                  else
                      minwrk = max( n+lwqp3, lwsvdj, n+lwlqf, 2_ilp*n+lwqrf,n+lwsvdj, n+lwunmlq )
                                
                  end if
                  if ( lquery ) then
                      call stdlib_cgesvj( 'L', 'U', 'N', n,n, u, ldu, sva, n, a,lda, cdummy, -1_ilp, &
                                rdummy, -1_ilp, ierr )
                      lwrk_cgesvj = real( cdummy(1_ilp),KIND=sp)
                      call stdlib_cunmlq( 'L', 'C', n, n, n, a, lda, cdummy,v, ldv, cdummy, -1_ilp, &
                                ierr )
                      lwrk_cunmlq = real( cdummy(1_ilp),KIND=sp)
                      if ( errest ) then
                      optwrk = max( n+lwrk_cgeqp3, lwcon, lwrk_cgesvj,n+lwrk_cgelqf, 2_ilp*n+&
                                lwrk_cgeqrf,n+lwrk_cgesvj,  n+lwrk_cunmlq )
                      else
                      optwrk = max( n+lwrk_cgeqp3, lwrk_cgesvj,n+lwrk_cgelqf,2_ilp*n+lwrk_cgeqrf, n+&
                                lwrk_cgesvj,n+lwrk_cunmlq )
                      end if
                  end if
                  if ( l2tran .or. rowpiv ) then
                       if ( errest ) then
                          minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj, lrwcon )
                       else
                          minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj )
                       end if
                  else
                       if ( errest ) then
                          minrwrk = max( 7_ilp, lrwqp3, lrwsvdj, lrwcon )
                       else
                          minrwrk = max( 7_ilp, lrwqp3, lrwsvdj )
                       end if
                  end if
                  if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
               else if ( lsvec .and. (.not.rsvec) ) then
                  ! Minimal And Optimal Sizes Of The Complex Workspace If The
                  ! singular values and the left singular vectors are requested
                  if ( errest ) then
                      minwrk = n + max( lwqp3,lwcon,n+lwqrf,lwsvdj,lwunmqrm )
                  else
                      minwrk = n + max( lwqp3, n+lwqrf, lwsvdj, lwunmqrm )
                  end if
                  if ( lquery ) then
                      call stdlib_cgesvj( 'L', 'U', 'N', n,n, u, ldu, sva, n, a,lda, cdummy, -1_ilp, &
                                rdummy, -1_ilp, ierr )
                      lwrk_cgesvj = real( cdummy(1_ilp),KIND=sp)
                      call stdlib_cunmqr( 'L', 'N', m, n, n, a, lda, cdummy, u,ldu, cdummy, -1_ilp, &
                                ierr )
                      lwrk_cunmqrm = real( cdummy(1_ilp),KIND=sp)
                      if ( errest ) then
                      optwrk = n + max( lwrk_cgeqp3, lwcon, n+lwrk_cgeqrf,lwrk_cgesvj, &
                                lwrk_cunmqrm )
                      else
                      optwrk = n + max( lwrk_cgeqp3, n+lwrk_cgeqrf,lwrk_cgesvj, lwrk_cunmqrm )
                                
                      end if
                  end if
                  if ( l2tran .or. rowpiv ) then
                      if ( errest ) then
                         minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj, lrwcon )
                      else
                         minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj )
                      end if
                  else
                      if ( errest ) then
                         minrwrk = max( 7_ilp, lrwqp3, lrwsvdj, lrwcon )
                      else
                         minrwrk = max( 7_ilp, lrwqp3, lrwsvdj )
                      end if
                  end if
                  if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
               else
                  ! Minimal And Optimal Sizes Of The Complex Workspace If The
                  ! full svd is requested
                  if ( .not. jracc ) then
                      if ( errest ) then
                         minwrk = max( n+lwqp3, n+lwcon,  2_ilp*n+n**2_ilp+lwcon,2_ilp*n+lwqrf,         2_ilp*n+&
                         lwqp3,2_ilp*n+n**2_ilp+n+lwlqf,  2_ilp*n+n**2_ilp+n+n**2_ilp+lwcon,2_ilp*n+n**2_ilp+n+lwsvdj, 2_ilp*n+&
                         n**2_ilp+n+lwsvdjv,2_ilp*n+n**2_ilp+n+lwunmqr,2_ilp*n+n**2_ilp+n+lwunmlq,n+n**2_ilp+lwsvdj,   n+&
                                   lwunmqrm )
                      else
                         minwrk = max( n+lwqp3,        2_ilp*n+n**2_ilp+lwcon,2_ilp*n+lwqrf,         2_ilp*n+&
                         lwqp3,2_ilp*n+n**2_ilp+n+lwlqf,  2_ilp*n+n**2_ilp+n+n**2_ilp+lwcon,2_ilp*n+n**2_ilp+n+lwsvdj, 2_ilp*n+&
                         n**2_ilp+n+lwsvdjv,2_ilp*n+n**2_ilp+n+lwunmqr,2_ilp*n+n**2_ilp+n+lwunmlq,n+n**2_ilp+lwsvdj,      &
                                   n+lwunmqrm )
                      end if
                      miniwrk = miniwrk + n
                      if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
                  else
                      if ( errest ) then
                         minwrk = max( n+lwqp3, n+lwcon, 2_ilp*n+lwqrf,2_ilp*n+n**2_ilp+lwsvdjv, 2_ilp*n+n**2_ilp+n+&
                                   lwunmqr,n+lwunmqrm )
                      else
                         minwrk = max( n+lwqp3, 2_ilp*n+lwqrf,2_ilp*n+n**2_ilp+lwsvdjv, 2_ilp*n+n**2_ilp+n+lwunmqr,n+&
                                   lwunmqrm )
                      end if
                      if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
                  end if
                  if ( lquery ) then
                      call stdlib_cunmqr( 'L', 'N', m, n, n, a, lda, cdummy, u,ldu, cdummy, -1_ilp, &
                                ierr )
                      lwrk_cunmqrm = real( cdummy(1_ilp),KIND=sp)
                      call stdlib_cunmqr( 'L', 'N', n, n, n, a, lda, cdummy, u,ldu, cdummy, -1_ilp, &
                                ierr )
                      lwrk_cunmqr = real( cdummy(1_ilp),KIND=sp)
                      if ( .not. jracc ) then
                          call stdlib_cgeqp3( n,n, a, lda, iwork, cdummy,cdummy, -1_ilp,rdummy, ierr )
                                    
                          lwrk_cgeqp3n = real( cdummy(1_ilp),KIND=sp)
                          call stdlib_cgesvj( 'L', 'U', 'N', n, n, u, ldu, sva,n, v, ldv, cdummy, &
                                    -1_ilp, rdummy, -1_ilp, ierr )
                          lwrk_cgesvj = real( cdummy(1_ilp),KIND=sp)
                          call stdlib_cgesvj( 'U', 'U', 'N', n, n, u, ldu, sva,n, v, ldv, cdummy, &
                                    -1_ilp, rdummy, -1_ilp, ierr )
                          lwrk_cgesvju = real( cdummy(1_ilp),KIND=sp)
                          call stdlib_cgesvj( 'L', 'U', 'V', n, n, u, ldu, sva,n, v, ldv, cdummy, &
                                    -1_ilp, rdummy, -1_ilp, ierr )
                          lwrk_cgesvjv = real( cdummy(1_ilp),KIND=sp)
                          call stdlib_cunmlq( 'L', 'C', n, n, n, a, lda, cdummy,v, ldv, cdummy, -&
                                    1_ilp, ierr )
                          lwrk_cunmlq = real( cdummy(1_ilp),KIND=sp)
                          if ( errest ) then
                            optwrk = max( n+lwrk_cgeqp3, n+lwcon,2_ilp*n+n**2_ilp+lwcon, 2_ilp*n+lwrk_cgeqrf,&
                            2_ilp*n+lwrk_cgeqp3n,2_ilp*n+n**2_ilp+n+lwrk_cgelqf,2_ilp*n+n**2_ilp+n+n**2_ilp+lwcon,2_ilp*n+&
                            n**2_ilp+n+lwrk_cgesvj,2_ilp*n+n**2_ilp+n+lwrk_cgesvjv,2_ilp*n+n**2_ilp+n+lwrk_cunmqr,2_ilp*n+&
                                      n**2_ilp+n+lwrk_cunmlq,n+n**2_ilp+lwrk_cgesvju,n+lwrk_cunmqrm )
                          else
                            optwrk = max( n+lwrk_cgeqp3,2_ilp*n+n**2_ilp+lwcon, 2_ilp*n+lwrk_cgeqrf,2_ilp*n+&
                            lwrk_cgeqp3n,2_ilp*n+n**2_ilp+n+lwrk_cgelqf,2_ilp*n+n**2_ilp+n+n**2_ilp+lwcon,2_ilp*n+n**2_ilp+n+&
                            lwrk_cgesvj,2_ilp*n+n**2_ilp+n+lwrk_cgesvjv,2_ilp*n+n**2_ilp+n+lwrk_cunmqr,2_ilp*n+n**2_ilp+n+&
                                      lwrk_cunmlq,n+n**2_ilp+lwrk_cgesvju,n+lwrk_cunmqrm )
                          end if
                      else
                          call stdlib_cgesvj( 'L', 'U', 'V', n, n, u, ldu, sva,n, v, ldv, cdummy, &
                                    -1_ilp, rdummy, -1_ilp, ierr )
                          lwrk_cgesvjv = real( cdummy(1_ilp),KIND=sp)
                          call stdlib_cunmqr( 'L', 'N', n, n, n, cdummy, n, cdummy,v, ldv, cdummy,&
                                     -1_ilp, ierr )
                          lwrk_cunmqr = real( cdummy(1_ilp),KIND=sp)
                          call stdlib_cunmqr( 'L', 'N', m, n, n, a, lda, cdummy, u,ldu, cdummy, -&
                                    1_ilp, ierr )
                          lwrk_cunmqrm = real( cdummy(1_ilp),KIND=sp)
                          if ( errest ) then
                             optwrk = max( n+lwrk_cgeqp3, n+lwcon,2_ilp*n+lwrk_cgeqrf, 2_ilp*n+n**2_ilp,2_ilp*n+&
                                       n**2_ilp+lwrk_cgesvjv,2_ilp*n+n**2_ilp+n+lwrk_cunmqr,n+lwrk_cunmqrm )
                          else
                             optwrk = max( n+lwrk_cgeqp3, 2_ilp*n+lwrk_cgeqrf,2_ilp*n+n**2_ilp, 2_ilp*n+n**2_ilp+&
                                       lwrk_cgesvjv,2_ilp*n+n**2_ilp+n+lwrk_cunmqr,n+lwrk_cunmqrm )
                          end if
                      end if
                  end if
                  if ( l2tran .or. rowpiv ) then
                      minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj, lrwcon )
                  else
                      minrwrk = max( 7_ilp, lrwqp3, lrwsvdj, lrwcon )
                  end if
               end if
               minwrk = max( 2_ilp, minwrk )
               optwrk = max( optwrk, minwrk )
               if ( lwork  < minwrk  .and. (.not.lquery) ) info = - 17_ilp
               if ( lrwork < minrwrk .and. (.not.lquery) ) info = - 19_ilp
           end if
           if ( info /= 0_ilp ) then
             ! #:(
              call stdlib_xerbla( 'CGEJSV', - info )
              return
           else if ( lquery ) then
               cwork(1_ilp) = optwrk
               cwork(2_ilp) = minwrk
               rwork(1_ilp) = minrwrk
               iwork(1_ilp) = max( 4_ilp, miniwrk )
               return
           end if
           ! quick return for void matrix (y3k safe)
       ! #:)
           if ( ( m == 0_ilp ) .or. ( n == 0_ilp ) ) then
              iwork(1_ilp:4_ilp) = 0_ilp
              rwork(1_ilp:7_ilp) = 0_ilp
              return
           endif
           ! determine whether the matrix u should be m x n or m x m
           if ( lsvec ) then
              n1 = n
              if ( stdlib_lsame( jobu, 'F' ) ) n1 = m
           end if
           ! set numerical parameters
      ! !    note: make sure stdlib_slamch() does not fail on the target architecture.
           epsln = stdlib_slamch('EPSILON')
           sfmin = stdlib_slamch('SAFEMINIMUM')
           small = sfmin / epsln
           big   = stdlib_slamch('O')
           ! big   = one / sfmin
           ! initialize sva(1:n) = diag( ||a e_i||_2 )_1^n
      ! (!)  if necessary, scale sva() to protect the largest norm from
           ! overflow. it is possible that this scaling pushes the smallest
           ! column norm left from the underflow threshold (extreme case).
           scalem  = one / sqrt(real(m,KIND=sp)*real(n,KIND=sp))
           noscal  = .true.
           goscal  = .true.
           do p = 1, n
              aapp = zero
              aaqq = one
              call stdlib_classq( m, a(1_ilp,p), 1_ilp, aapp, aaqq )
              if ( aapp > big ) then
                 info = - 9_ilp
                 call stdlib_xerbla( 'CGEJSV', -info )
                 return
              end if
              aaqq = sqrt(aaqq)
              if ( ( aapp < (big / aaqq) ) .and. noscal  ) then
                 sva(p)  = aapp * aaqq
              else
                 noscal  = .false.
                 sva(p)  = aapp * ( aaqq * scalem )
                 if ( goscal ) then
                    goscal = .false.
                    call stdlib_sscal( p-1, scalem, sva, 1_ilp )
                 end if
              end if
           end do
           if ( noscal ) scalem = one
           aapp = zero
           aaqq = big
           do p = 1, n
              aapp = max( aapp, sva(p) )
              if ( sva(p) /= zero ) aaqq = min( aaqq, sva(p) )
           end do
           ! quick return for zero m x n matrix
       ! #:)
           if ( aapp == zero ) then
              if ( lsvec ) call stdlib_claset( 'G', m, n1, czero, cone, u, ldu )
              if ( rsvec ) call stdlib_claset( 'G', n, n,  czero, cone, v, ldv )
              rwork(1_ilp) = one
              rwork(2_ilp) = one
              if ( errest ) rwork(3_ilp) = one
              if ( lsvec .and. rsvec ) then
                 rwork(4_ilp) = one
                 rwork(5_ilp) = one
              end if
              if ( l2tran ) then
                 rwork(6_ilp) = zero
                 rwork(7_ilp) = zero
              end if
              iwork(1_ilp) = 0_ilp
              iwork(2_ilp) = 0_ilp
              iwork(3_ilp) = 0_ilp
              iwork(4_ilp) = -1_ilp
              return
           end if
           ! issue warning if denormalized column norms detected. override the
           ! high relative accuracy request. issue licence to kill nonzero columns
           ! (set them to zero) whose norm is less than sigma_max / big (roughly).
       ! #:(
           warning = 0_ilp
           if ( aaqq <= sfmin ) then
              l2rank = .true.
              l2kill = .true.
              warning = 1_ilp
           end if
           ! quick return for one-column matrix
       ! #:)
           if ( n == 1_ilp ) then
              if ( lsvec ) then
                 call stdlib_clascl( 'G',0_ilp,0_ilp,sva(1_ilp),scalem, m,1_ilp,a(1_ilp,1_ilp),lda,ierr )
                 call stdlib_clacpy( 'A', m, 1_ilp, a, lda, u, ldu )
                 ! computing all m left singular vectors of the m x 1 matrix
                 if ( n1 /= n  ) then
                   call stdlib_cgeqrf( m, n, u,ldu, cwork, cwork(n+1),lwork-n,ierr )
                   call stdlib_cungqr( m,n1,1_ilp, u,ldu,cwork,cwork(n+1),lwork-n,ierr )
                   call stdlib_ccopy( m, a(1_ilp,1_ilp), 1_ilp, u(1_ilp,1_ilp), 1_ilp )
                 end if
              end if
              if ( rsvec ) then
                  v(1_ilp,1_ilp) = cone
              end if
              if ( sva(1_ilp) < (big*scalem) ) then
                 sva(1_ilp)  = sva(1_ilp) / scalem
                 scalem  = one
              end if
              rwork(1_ilp) = one / scalem
              rwork(2_ilp) = one
              if ( sva(1_ilp) /= zero ) then
                 iwork(1_ilp) = 1_ilp
                 if ( ( sva(1_ilp) / scalem) >= sfmin ) then
                    iwork(2_ilp) = 1_ilp
                 else
                    iwork(2_ilp) = 0_ilp
                 end if
              else
                 iwork(1_ilp) = 0_ilp
                 iwork(2_ilp) = 0_ilp
              end if
              iwork(3_ilp) = 0_ilp
              iwork(4_ilp) = -1_ilp
              if ( errest ) rwork(3_ilp) = one
              if ( lsvec .and. rsvec ) then
                 rwork(4_ilp) = one
                 rwork(5_ilp) = one
              end if
              if ( l2tran ) then
                 rwork(6_ilp) = zero
                 rwork(7_ilp) = zero
              end if
              return
           end if
           transp = .false.
           aatmax = -one
           aatmin =  big
           if ( rowpiv .or. l2tran ) then
           ! compute the row norms, needed to determine row pivoting sequence
           ! (in the case of heavily row weighted a, row pivoting is strongly
           ! advised) and to collect information needed to compare the
           ! structures of a * a^* and a^* * a (in the case l2tran==.true.).
              if ( l2tran ) then
                 do p = 1, m
                    xsc   = zero
                    temp1 = one
                    call stdlib_classq( n, a(p,1_ilp), lda, xsc, temp1 )
                    ! stdlib_classq gets both the ell_2 and the ell_infinity norm
                    ! in one pass through the vector
                    rwork(m+p)  = xsc * scalem
                    rwork(p)    = xsc * (scalem*sqrt(temp1))
                    aatmax = max( aatmax, rwork(p) )
                    if (rwork(p) /= zero)aatmin = min(aatmin,rwork(p))
                 end do
              else
                 do p = 1, m
                    rwork(m+p) = scalem*abs( a(p,stdlib_icamax(n,a(p,1_ilp),lda)) )
                    aatmax = max( aatmax, rwork(m+p) )
                    aatmin = min( aatmin, rwork(m+p) )
                 end do
              end if
           end if
           ! for square matrix a try to determine whether a^*  would be better
           ! input for the preconditioned jacobi svd, with faster convergence.
           ! the decision is based on an o(n) function of the vector of column
           ! and row norms of a, based on the shannon entropy. this should give
           ! the right choice in most cases when the difference actually matters.
           ! it may fail and pick the slower converging side.
           entra  = zero
           entrat = zero
           if ( l2tran ) then
              xsc   = zero
              temp1 = one
              call stdlib_slassq( n, sva, 1_ilp, xsc, temp1 )
              temp1 = one / temp1
              entra = zero
              do p = 1, n
                 big1  = ( ( sva(p) / xsc )**2_ilp ) * temp1
                 if ( big1 /= zero ) entra = entra + big1 * log(big1)
              end do
              entra = - entra / log(real(n,KIND=sp))
              ! now, sva().^2/trace(a^* * a) is a point in the probability simplex.
              ! it is derived from the diagonal of  a^* * a.  do the same with the
              ! diagonal of a * a^*, compute the entropy of the corresponding
              ! probability distribution. note that a * a^* and a^* * a have the
              ! same trace.
              entrat = zero
              do p = 1, m
                 big1 = ( ( rwork(p) / xsc )**2_ilp ) * temp1
                 if ( big1 /= zero ) entrat = entrat + big1 * log(big1)
              end do
              entrat = - entrat / log(real(m,KIND=sp))
              ! analyze the entropies and decide a or a^*. smaller entropy
              ! usually means better input for the algorithm.
              transp = ( entrat < entra )
              ! if a^* is better than a, take the adjoint of a. this is allowed
              ! only for square matrices, m=n.
              if ( transp ) then
                 ! in an optimal implementation, this trivial transpose
                 ! should be replaced with faster transpose.
                 do p = 1, n - 1
                    a(p,p) = conjg(a(p,p))
                    do q = p + 1, n
                        ctemp = conjg(a(q,p))
                       a(q,p) = conjg(a(p,q))
                       a(p,q) = ctemp
                    end do
                 end do
                 a(n,n) = conjg(a(n,n))
                 do p = 1, n
                    rwork(m+p) = sva(p)
                    sva(p) = rwork(p)
                    ! previously computed row 2-norms are now column 2-norms
                    ! of the transposed matrix
                 end do
                 temp1  = aapp
                 aapp   = aatmax
                 aatmax = temp1
                 temp1  = aaqq
                 aaqq   = aatmin
                 aatmin = temp1
                 kill   = lsvec
                 lsvec  = rsvec
                 rsvec  = kill
                 if ( lsvec ) n1 = n
                 rowpiv = .true.
              end if
           end if
           ! end if l2tran
           ! scale the matrix so that its maximal singular value remains less
           ! than sqrt(big) -- the matrix is scaled so that its maximal column
           ! has euclidean norm equal to sqrt(big/n). the only reason to keep
           ! sqrt(big) instead of big is the fact that stdlib_cgejsv uses lapack and
           ! blas routines that, in some implementations, are not capable of
           ! working in the full interval [sfmin,big] and that they may provoke
           ! overflows in the intermediate results. if the singular values spread
           ! from sfmin to big, then stdlib_cgesvj will compute them. so, in that case,
           ! one should use stdlib_cgesvj instead of stdlib_cgejsv.
           big1   = sqrt( big )
           temp1  = sqrt( big / real(n,KIND=sp) )
           ! >> for future updates: allow bigger range, i.e. the largest column
           ! will be allowed up to big/n and stdlib_cgesvj will do the rest. however, for
           ! this all other (lapack) components must allow such a range.
           ! temp1  = big/real(n,KIND=sp)
           ! temp1  = big * epsln  this should 'almost' work with current lapack components
           call stdlib_slascl( 'G', 0_ilp, 0_ilp, aapp, temp1, n, 1_ilp, sva, n, ierr )
           if ( aaqq > (aapp * sfmin) ) then
               aaqq = ( aaqq / aapp ) * temp1
           else
               aaqq = ( aaqq * temp1 ) / aapp
           end if
           temp1 = temp1 * scalem
           call stdlib_clascl( 'G', 0_ilp, 0_ilp, aapp, temp1, m, n, a, lda, ierr )
           ! to undo scaling at the end of this procedure, multiply the
           ! computed singular values with uscal2 / uscal1.
           uscal1 = temp1
           uscal2 = aapp
           if ( l2kill ) then
              ! l2kill enforces computation of nonzero singular values in
              ! the restricted range of condition number of the initial a,
              ! sigma_max(a) / sigma_min(a) approx. sqrt(big)/sqrt(sfmin).
              xsc = sqrt( sfmin )
           else
              xsc = small
              ! now, if the condition number of a is too big,
              ! sigma_max(a) / sigma_min(a) > sqrt(big/n) * epsln / sfmin,
              ! as a precaution measure, the full svd is computed using stdlib_cgesvj
              ! with accumulated jacobi rotations. this provides numerically
              ! more robust computation, at the cost of slightly increased run
              ! time. depending on the concrete implementation of blas and lapack
              ! (i.e. how they behave in presence of extreme ill-conditioning) the
              ! implementor may decide to remove this switch.
              if ( ( aaqq<sqrt(sfmin) ) .and. lsvec .and. rsvec ) then
                 jracc = .true.
              end if
           end if
           if ( aaqq < xsc ) then
              do p = 1, n
                 if ( sva(p) < xsc ) then
                    call stdlib_claset( 'A', m, 1_ilp, czero, czero, a(1_ilp,p), lda )
                    sva(p) = zero
                 end if
              end do
           end if
           ! preconditioning using qr factorization with pivoting
           if ( rowpiv ) then
              ! optional row permutation (bjoerck row pivoting):
              ! a result by cox and higham shows that the bjoerck's
              ! row pivoting combined with standard column pivoting
              ! has similar effect as powell-reid complete pivoting.
              ! the ell-infinity norms of a are made nonincreasing.
              if ( ( lsvec .and. rsvec ) .and. .not.( jracc ) ) then
                   iwoff = 2_ilp*n
              else
                   iwoff = n
              end if
              do p = 1, m - 1
                 q = stdlib_isamax( m-p+1, rwork(m+p), 1_ilp ) + p - 1_ilp
                 iwork(iwoff+p) = q
                 if ( p /= q ) then
                    temp1      = rwork(m+p)
                    rwork(m+p) = rwork(m+q)
                    rwork(m+q) = temp1
                 end if
              end do
              call stdlib_claswp( n, a, lda, 1_ilp, m-1, iwork(iwoff+1), 1_ilp )
           end if
           ! end of the preparation phase (scaling, optional sorting and
           ! transposing, optional flushing of small columns).
           ! preconditioning
           ! if the full svd is needed, the right singular vectors are computed
           ! from a matrix equation, and for that we need theoretical analysis
           ! of the businger-golub pivoting. so we use stdlib_cgeqp3 as the first rr qrf.
           ! in all other cases the first rr qrf can be chosen by other criteria
           ! (eg speed by replacing global with restricted window pivoting, such
           ! as in xgeqpx from toms # 782). good results will be obtained using
           ! xgeqpx with properly (!) chosen numerical parameters.
           ! any improvement of stdlib_cgeqp3 improves overall performance of stdlib_cgejsv.
           ! a * p1 = q1 * [ r1^* 0]^*:
           do p = 1, n
              ! All Columns Are Free Columns
              iwork(p) = 0_ilp
           end do
           call stdlib_cgeqp3( m, n, a, lda, iwork, cwork, cwork(n+1), lwork-n,rwork, ierr )
                     
           ! the upper triangular matrix r1 from the first qrf is inspected for
           ! rank deficiency and possibilities for deflation, or possible
           ! ill-conditioning. depending on the user specified flag l2rank,
           ! the procedure explores possibilities to reduce the numerical
           ! rank by inspecting the computed upper triangular factor. if
           ! l2rank or l2aber are up, then stdlib_cgejsv will compute the svd of
           ! a + da, where ||da|| <= f(m,n)*epsln.
           nr = 1_ilp
           if ( l2aber ) then
              ! standard absolute error bound suffices. all sigma_i with
              ! sigma_i < n*epsln*||a|| are flushed to zero. this is an
              ! aggressive enforcement of lower numerical rank by introducing a
              ! backward error of the order of n*epsln*||a||.
              temp1 = sqrt(real(n,KIND=sp))*epsln
              loop_3002: do p = 2, n
                 if ( abs(a(p,p)) >= (temp1*abs(a(1_ilp,1_ilp))) ) then
                    nr = nr + 1_ilp
                 else
                    exit loop_3002
                 end if
              end do loop_3002
           else if ( l2rank ) then
              ! .. similarly as above, only slightly more gentle (less aggressive).
              ! sudden drop on the diagonal of r1 is used as the criterion for
              ! close-to-rank-deficient.
              temp1 = sqrt(sfmin)
              loop_3402: do p = 2, n
                 if ( ( abs(a(p,p)) < (epsln*abs(a(p-1,p-1))) ) .or.( abs(a(p,p)) < small ) .or.( &
                           l2kill .and. (abs(a(p,p)) < temp1) ) ) exit loop_3402
                 nr = nr + 1_ilp
              end do loop_3402
           else
              ! the goal is high relative accuracy. however, if the matrix
              ! has high scaled condition number the relative accuracy is in
              ! general not feasible. later on, a condition number estimator
              ! will be deployed to estimate the scaled condition number.
              ! here we just remove the underflowed part of the triangular
              ! factor. this prevents the situation in which the code is
              ! working hard to get the accuracy not warranted by the data.
              temp1  = sqrt(sfmin)
              loop_3302: do p = 2, n
                 if ( ( abs(a(p,p)) < small ) .or.( l2kill .and. (abs(a(p,p)) < temp1) ) ) exit loop_3302
                 nr = nr + 1_ilp
              end do loop_3302
           end if
           almort = .false.
           if ( nr == n ) then
              maxprj = one
              do p = 2, n
                 temp1  = abs(a(p,p)) / sva(iwork(p))
                 maxprj = min( maxprj, temp1 )
              end do
              if ( maxprj**2_ilp >= one - real(n,KIND=sp)*epsln ) almort = .true.
           end if
           sconda = - one
           condr1 = - one
           condr2 = - one
           if ( errest ) then
              if ( n == nr ) then
                 if ( rsvec ) then
                    ! V Is Available As Workspace
                    call stdlib_clacpy( 'U', n, n, a, lda, v, ldv )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_csscal( p, one/temp1, v(1_ilp,p), 1_ilp )
                    end do
                    if ( lsvec )then
                        call stdlib_cpocon( 'U', n, v, ldv, one, temp1,cwork(n+1), rwork, ierr )
                                  
                    else
                        call stdlib_cpocon( 'U', n, v, ldv, one, temp1,cwork, rwork, ierr )
                                  
                    end if
                 else if ( lsvec ) then
                    ! U Is Available As Workspace
                    call stdlib_clacpy( 'U', n, n, a, lda, u, ldu )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_csscal( p, one/temp1, u(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_cpocon( 'U', n, u, ldu, one, temp1,cwork(n+1), rwork, ierr )
                              
                 else
                    call stdlib_clacpy( 'U', n, n, a, lda, cwork, n )
      ! []            call stdlib_clacpy( 'u', n, n, a, lda, cwork(n+1), n )
                    ! change: here index shifted by n to the left, cwork(1:n)
                    ! not needed for sigma only computation
                    do p = 1, n
                       temp1 = sva(iwork(p))
      ! []               call stdlib_csscal( p, one/temp1, cwork(n+(p-1)*n+1), 1 )
                       call stdlib_csscal( p, one/temp1, cwork((p-1)*n+1), 1_ilp )
                    end do
                 ! The Columns Of R Are Scaled To Have Unit Euclidean Lengths
      ! []               call stdlib_cpocon( 'u', n, cwork(n+1), n, one, temp1,
      ! []     $              cwork(n+n*n+1), rwork, ierr )
                    call stdlib_cpocon( 'U', n, cwork, n, one, temp1,cwork(n*n+1), rwork, ierr )
                              
                 end if
                 if ( temp1 /= zero ) then
                    sconda = one / sqrt(temp1)
                 else
                    sconda = - one
                 end if
                 ! sconda is an estimate of sqrt(||(r^* * r)^(-1)||_1).
                 ! n^(-1/4) * sconda <= ||r^(-1)||_2 <= n^(1/4) * sconda
              else
                 sconda = - one
              end if
           end if
           l2pert = l2pert .and. ( abs( a(1_ilp,1_ilp)/a(nr,nr) ) > sqrt(big1) )
           ! if there is no violent scaling, artificial perturbation is not needed.
           ! phase 3:
           if ( .not. ( rsvec .or. lsvec ) ) then
               ! singular values only
               ! .. transpose a(1:nr,1:n)
              do p = 1, min( n-1, nr )
                 call stdlib_ccopy( n-p, a(p,p+1), lda, a(p+1,p), 1_ilp )
                 call stdlib_clacgv( n-p+1, a(p,p), 1_ilp )
              end do
              if ( nr == n ) a(n,n) = conjg(a(n,n))
              ! the following two do-loops introduce small relative perturbation
              ! into the strict upper triangle of the lower triangular matrix.
              ! small entries below the main diagonal are also changed.
              ! this modification is useful if the computing environment does not
              ! provide/allow flush to zero underflow, for it prevents many
              ! annoying denormalized numbers in case of strongly scaled matrices.
              ! the perturbation is structured so that it does not introduce any
              ! new perturbation of the singular values, and it does not destroy
              ! the job done by the preconditioner.
              ! the licence for this perturbation is in the variable l2pert, which
              ! should be .false. if flush to zero underflow is active.
              if ( .not. almort ) then
                 if ( l2pert ) then
                    ! xsc = sqrt(small)
                    xsc = epsln / real(n,KIND=sp)
                    do q = 1, nr
                       ctemp = cmplx(xsc*abs(a(q,q)),zero,KIND=sp)
                       do p = 1, n
                          if ( ( (p>q) .and. (abs(a(p,q))<=temp1) ).or. ( p < q ) )a(p,q) = &
                                    ctemp
           ! $                     a(p,q) = temp1 * ( a(p,q) / abs(a(p,q)) )
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_claset( 'U', nr-1,nr-1, czero,czero, a(1_ilp,2_ilp),lda )
                 end if
                  ! Second Preconditioning Using The Qr Factorization
                 call stdlib_cgeqrf( n,nr, a,lda, cwork, cwork(n+1),lwork-n, ierr )
                 ! And Transpose Upper To Lower Triangular
                 do p = 1, nr - 1
                    call stdlib_ccopy( nr-p, a(p,p+1), lda, a(p+1,p), 1_ilp )
                    call stdlib_clacgv( nr-p+1, a(p,p), 1_ilp )
                 end do
              end if
                 ! row-cyclic jacobi svd algorithm with column pivoting
                 ! .. again some perturbation (a "background noise") is added
                 ! to drown denormals
                 if ( l2pert ) then
                    ! xsc = sqrt(small)
                    xsc = epsln / real(n,KIND=sp)
                    do q = 1, nr
                       ctemp = cmplx(xsc*abs(a(q,q)),zero,KIND=sp)
                       do p = 1, nr
                          if ( ( (p>q) .and. (abs(a(p,q))<=temp1) ).or. ( p < q ) )a(p,q) = &
                                    ctemp
           ! $                   a(p,q) = temp1 * ( a(p,q) / abs(a(p,q)) )
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_claset( 'U', nr-1, nr-1, czero, czero, a(1_ilp,2_ilp), lda )
                 end if
                 ! .. and one-sided jacobi rotations are started on a lower
                 ! triangular matrix (plus perturbation which is ignored in
                 ! the part which destroys triangular form (confusing?!))
                 call stdlib_cgesvj( 'L', 'N', 'N', nr, nr, a, lda, sva,n, v, ldv, cwork, lwork, &
                           rwork, lrwork, info )
                 scalem  = rwork(1_ilp)
                 numrank = nint(rwork(2_ilp),KIND=ilp)
           else if ( ( rsvec .and. ( .not. lsvec ) .and. ( .not. jracc ) ).or.( jracc .and. ( &
                     .not. lsvec ) .and. ( nr /= n ) ) ) then
              ! -> singular values and right singular vectors <-
              if ( almort ) then
                 ! In This Case Nr Equals N
                 do p = 1, nr
                    call stdlib_ccopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                    call stdlib_clacgv( n-p+1, v(p,p), 1_ilp )
                 end do
                 if (nr>1_ilp) call stdlib_claset( 'U', nr-1,nr-1, czero, czero, v(1_ilp,2_ilp), ldv )
                 call stdlib_cgesvj( 'L','U','N', n, nr, v, ldv, sva, nr, a, lda,cwork, lwork, &
                           rwork, lrwork, info )
                 scalem  = rwork(1_ilp)
                 numrank = nint(rwork(2_ilp),KIND=ilp)
              else
              ! .. two more qr factorizations ( one qrf is not enough, two require
              ! accumulated product of jacobi rotations, three are perfect )
                 if (nr>1_ilp) call stdlib_claset( 'L', nr-1,nr-1, czero, czero, a(2_ilp,1_ilp), lda )
                 call stdlib_cgelqf( nr,n, a, lda, cwork, cwork(n+1), lwork-n, ierr)
                 call stdlib_clacpy( 'L', nr, nr, a, lda, v, ldv )
                 if (nr>1_ilp) call stdlib_claset( 'U', nr-1,nr-1, czero, czero, v(1_ilp,2_ilp), ldv )
                 call stdlib_cgeqrf( nr, nr, v, ldv, cwork(n+1), cwork(2_ilp*n+1),lwork-2*n, ierr )
                           
                 do p = 1, nr
                    call stdlib_ccopy( nr-p+1, v(p,p), ldv, v(p,p), 1_ilp )
                    call stdlib_clacgv( nr-p+1, v(p,p), 1_ilp )
                 end do
                 if (nr>1_ilp) call stdlib_claset('U', nr-1, nr-1, czero, czero, v(1_ilp,2_ilp), ldv)
                 call stdlib_cgesvj( 'L', 'U','N', nr, nr, v,ldv, sva, nr, u,ldu, cwork(n+1), &
                           lwork-n, rwork, lrwork, info )
                 scalem  = rwork(1_ilp)
                 numrank = nint(rwork(2_ilp),KIND=ilp)
                 if ( nr < n ) then
                    call stdlib_claset( 'A',n-nr, nr, czero,czero, v(nr+1,1_ilp),  ldv )
                    call stdlib_claset( 'A',nr, n-nr, czero,czero, v(1_ilp,nr+1),  ldv )
                    call stdlib_claset( 'A',n-nr,n-nr,czero,cone, v(nr+1,nr+1),ldv )
                 end if
              call stdlib_cunmlq( 'L', 'C', n, n, nr, a, lda, cwork,v, ldv, cwork(n+1), lwork-n, &
                        ierr )
              end if
               ! Permute The Rows Of V
               ! do 8991 p = 1, n
                  ! call stdlib_ccopy( n, v(p,1), ldv, a(iwork(p),1), lda )
                  8991 continue
               ! call stdlib_clacpy( 'all', n, n, a, lda, v, ldv )
              call stdlib_clapmr( .false., n, n, v, ldv, iwork )
               if ( transp ) then
                 call stdlib_clacpy( 'A', n, n, v, ldv, u, ldu )
               end if
           else if ( jracc .and. (.not. lsvec) .and. ( nr== n ) ) then
              if (n>1_ilp) call stdlib_claset( 'L', n-1,n-1, czero, czero, a(2_ilp,1_ilp), lda )
              call stdlib_cgesvj( 'U','N','V', n, n, a, lda, sva, n, v, ldv,cwork, lwork, rwork, &
                        lrwork, info )
               scalem  = rwork(1_ilp)
               numrank = nint(rwork(2_ilp),KIND=ilp)
               call stdlib_clapmr( .false., n, n, v, ldv, iwork )
           else if ( lsvec .and. ( .not. rsvec ) ) then
              ! Singular Values And Left Singular Vectors                 
              ! Second Preconditioning Step To Avoid Need To Accumulate
              ! jacobi rotations in the jacobi iterations.
              do p = 1, nr
                 call stdlib_ccopy( n-p+1, a(p,p), lda, u(p,p), 1_ilp )
                 call stdlib_clacgv( n-p+1, u(p,p), 1_ilp )
              end do
              if (nr>1_ilp) call stdlib_claset( 'U', nr-1, nr-1, czero, czero, u(1_ilp,2_ilp), ldu )
              call stdlib_cgeqrf( n, nr, u, ldu, cwork(n+1), cwork(2_ilp*n+1),lwork-2*n, ierr )
                        
              do p = 1, nr - 1
                 call stdlib_ccopy( nr-p, u(p,p+1), ldu, u(p+1,p), 1_ilp )
                 call stdlib_clacgv( n-p+1, u(p,p), 1_ilp )
              end do
              if (nr>1_ilp) call stdlib_claset( 'U', nr-1, nr-1, czero, czero, u(1_ilp,2_ilp), ldu )
              call stdlib_cgesvj( 'L', 'U', 'N', nr,nr, u, ldu, sva, nr, a,lda, cwork(n+1), lwork-&
                        n, rwork, lrwork, info )
              scalem  = rwork(1_ilp)
              numrank = nint(rwork(2_ilp),KIND=ilp)
              if ( nr < m ) then
                 call stdlib_claset( 'A',  m-nr, nr,czero, czero, u(nr+1,1_ilp), ldu )
                 if ( nr < n1 ) then
                    call stdlib_claset( 'A',nr, n1-nr, czero, czero, u(1_ilp,nr+1),ldu )
                    call stdlib_claset( 'A',m-nr,n1-nr,czero,cone,u(nr+1,nr+1),ldu )
                 end if
              end if
              call stdlib_cunmqr( 'L', 'N', m, n1, n, a, lda, cwork, u,ldu, cwork(n+1), lwork-n, &
                        ierr )
              if ( rowpiv )call stdlib_claswp( n1, u, ldu, 1_ilp, m-1, iwork(iwoff+1), -1_ilp )
              do p = 1, n1
                 xsc = one / stdlib_scnrm2( m, u(1_ilp,p), 1_ilp )
                 call stdlib_csscal( m, xsc, u(1_ilp,p), 1_ilp )
              end do
              if ( transp ) then
                 call stdlib_clacpy( 'A', n, n, u, ldu, v, ldv )
              end if
           else
              ! Full Svd 
              if ( .not. jracc ) then
              if ( .not. almort ) then
                 ! second preconditioning step (qrf [with pivoting])
                 ! note that the composition of transpose, qrf and transpose is
                 ! equivalent to an lqf call. since in many libraries the qrf
                 ! seems to be better optimized than the lqf, we do explicit
                 ! transpose and use the qrf. this is subject to changes in an
                 ! optimized implementation of stdlib_cgejsv.
                 do p = 1, nr
                    call stdlib_ccopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                    call stdlib_clacgv( n-p+1, v(p,p), 1_ilp )
                 end do
                 ! The Following Two Loops Perturb Small Entries To Avoid
                 ! denormals in the second qr factorization, where they are
                 ! as good as zeros. this is done to avoid painfully slow
                 ! computation with denormals. the relative size of the perturbation
                 ! is a parameter that can be changed by the implementer.
                 ! this perturbation device will be obsolete on machines with
                 ! properly implemented arithmetic.
                 ! to switch it off, set l2pert=.false. to remove it from  the
                 ! code, remove the action under l2pert=.true., leave the else part.
                 ! the following two loops should be blocked and fused with the
                 ! transposed copy above.
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do q = 1, nr
                       ctemp = cmplx(xsc*abs( v(q,q) ),zero,KIND=sp)
                       do p = 1, n
                          if ( ( p > q ) .and. ( abs(v(p,q)) <= temp1 ).or. ( p < q ) )v(p,q) = &
                                    ctemp
           ! $                   v(p,q) = temp1 * ( v(p,q) / abs(v(p,q)) )
                          if ( p < q ) v(p,q) = - v(p,q)
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_claset( 'U', nr-1, nr-1, czero, czero, v(1_ilp,2_ilp), ldv )
                 end if
                 ! estimate the row scaled condition number of r1
                 ! (if r1 is rectangular, n > nr, then the condition number
                 ! of the leading nr x nr submatrix is estimated.)
                 call stdlib_clacpy( 'L', nr, nr, v, ldv, cwork(2_ilp*n+1), nr )
                 do p = 1, nr
                    temp1 = stdlib_scnrm2(nr-p+1,cwork(2_ilp*n+(p-1)*nr+p),1_ilp)
                    call stdlib_csscal(nr-p+1,one/temp1,cwork(2_ilp*n+(p-1)*nr+p),1_ilp)
                 end do
                 call stdlib_cpocon('L',nr,cwork(2_ilp*n+1),nr,one,temp1,cwork(2_ilp*n+nr*nr+1),rwork,&
                           ierr)
                 condr1 = one / sqrt(temp1)
                 ! Here Need A Second Opinion On The Condition Number
                 ! Then Assume Worst Case Scenario
                 ! r1 is ok for inverse <=> condr1 < real(n,KIND=sp)
                 ! more conservative    <=> condr1 < sqrt(real(n,KIND=sp))
                 cond_ok = sqrt(sqrt(real(nr,KIND=sp)))
      ! [tp]       cond_ok is a tuning parameter.
                 if ( condr1 < cond_ok ) then
                    ! .. the second qrf without pivoting. note: in an optimized
                    ! implementation, this qrf should be implemented as the qrf
                    ! of a lower triangular matrix.
                    ! r1^* = q2 * r2
                    call stdlib_cgeqrf( n, nr, v, ldv, cwork(n+1), cwork(2_ilp*n+1),lwork-2*n, ierr )
                              
                    if ( l2pert ) then
                       xsc = sqrt(small)/epsln
                       do p = 2, nr
                          do q = 1, p - 1
                             ctemp=cmplx(xsc*min(abs(v(p,p)),abs(v(q,q))),zero,KIND=sp)
                             if ( abs(v(q,p)) <= temp1 )v(q,p) = ctemp
           ! $                     v(q,p) = temp1 * ( v(q,p) / abs(v(q,p)) )
                          end do
                       end do
                    end if
                    if ( nr /= n )call stdlib_clacpy( 'A', n, nr, v, ldv, cwork(2_ilp*n+1), n )
                              
                    ! .. save ...
                 ! This Transposed Copy Should Be Better Than Naive
                    do p = 1, nr - 1
                       call stdlib_ccopy( nr-p, v(p,p+1), ldv, v(p+1,p), 1_ilp )
                       call stdlib_clacgv(nr-p+1, v(p,p), 1_ilp )
                    end do
                    v(nr,nr)=conjg(v(nr,nr))
                    condr2 = condr1
                 else
                    ! .. ill-conditioned case: second qrf with pivoting
                    ! note that windowed pivoting would be equally good
                    ! numerically, and more run-time efficient. so, in
                    ! an optimal implementation, the next call to stdlib_cgeqp3
                    ! should be replaced with eg. call cgeqpx (acm toms #782)
                    ! with properly (carefully) chosen parameters.
                    ! r1^* * p2 = q2 * r2
                    do p = 1, nr
                       iwork(n+p) = 0_ilp
                    end do
                    call stdlib_cgeqp3( n, nr, v, ldv, iwork(n+1), cwork(n+1),cwork(2_ilp*n+1), lwork-&
                              2_ilp*n, rwork, ierr )
      ! *               call stdlib_cgeqrf( n, nr, v, ldv, cwork(n+1), cwork(2*n+1),
      ! *     $              lwork-2*n, ierr )
                    if ( l2pert ) then
                       xsc = sqrt(small)
                       do p = 2, nr
                          do q = 1, p - 1
                             ctemp=cmplx(xsc*min(abs(v(p,p)),abs(v(q,q))),zero,KIND=sp)
                             if ( abs(v(q,p)) <= temp1 )v(q,p) = ctemp
           ! $                     v(q,p) = temp1 * ( v(q,p) / abs(v(q,p)) )
                          end do
                       end do
                    end if
                    call stdlib_clacpy( 'A', n, nr, v, ldv, cwork(2_ilp*n+1), n )
                    if ( l2pert ) then
                       xsc = sqrt(small)
                       do p = 2, nr
                          do q = 1, p - 1
                             ctemp=cmplx(xsc*min(abs(v(p,p)),abs(v(q,q))),zero,KIND=sp)
                              ! v(p,q) = - temp1*( v(q,p) / abs(v(q,p)) )
                             v(p,q) = - ctemp
                          end do
                       end do
                    else
                       if (nr>1_ilp) call stdlib_claset( 'L',nr-1,nr-1,czero,czero,v(2_ilp,1_ilp),ldv )
                    end if
                    ! now, compute r2 = l3 * q3, the lq factorization.
                    call stdlib_cgelqf( nr, nr, v, ldv, cwork(2_ilp*n+n*nr+1),cwork(2_ilp*n+n*nr+nr+1), &
                              lwork-2*n-n*nr-nr, ierr )
                    ! And Estimate The Condition Number
                    call stdlib_clacpy( 'L',nr,nr,v,ldv,cwork(2_ilp*n+n*nr+nr+1),nr )
                    do p = 1, nr
                       temp1 = stdlib_scnrm2( p, cwork(2_ilp*n+n*nr+nr+p), nr )
                       call stdlib_csscal( p, one/temp1, cwork(2_ilp*n+n*nr+nr+p), nr )
                    end do
                    call stdlib_cpocon( 'L',nr,cwork(2_ilp*n+n*nr+nr+1),nr,one,temp1,cwork(2_ilp*n+n*nr+&
                              nr+nr*nr+1),rwork,ierr )
                    condr2 = one / sqrt(temp1)
                    if ( condr2 >= cond_ok ) then
                       ! Save The Householder Vectors Used For Q3
                       ! (this overwrites the copy of r2, as it will not be
                       ! needed in this branch, but it does not overwritte the
                       ! huseholder vectors of q2.).
                       call stdlib_clacpy( 'U', nr, nr, v, ldv, cwork(2_ilp*n+1), n )
                       ! And The Rest Of The Information On Q3 Is In
                       ! work(2*n+n*nr+1:2*n+n*nr+n)
                    end if
                 end if
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do q = 2, nr
                       ctemp = xsc * v(q,q)
                       do p = 1, q - 1
                           ! v(p,q) = - temp1*( v(p,q) / abs(v(p,q)) )
                          v(p,q) = - ctemp
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_claset( 'U', nr-1,nr-1, czero,czero, v(1_ilp,2_ilp), ldv )
                 end if
              ! second preconditioning finished; continue with jacobi svd
              ! the input matrix is lower trinagular.
              ! recover the right singular vectors as solution of a well
              ! conditioned triangular matrix equation.
                 if ( condr1 < cond_ok ) then
                    call stdlib_cgesvj( 'L','U','N',nr,nr,v,ldv,sva,nr,u, ldu,cwork(2_ilp*n+n*nr+nr+1)&
                              ,lwork-2*n-n*nr-nr,rwork,lrwork, info )
                    scalem  = rwork(1_ilp)
                    numrank = nint(rwork(2_ilp),KIND=ilp)
                    do p = 1, nr
                       call stdlib_ccopy(  nr, v(1_ilp,p), 1_ilp, u(1_ilp,p), 1_ilp )
                       call stdlib_csscal( nr, sva(p),    v(1_ilp,p), 1_ilp )
                    end do
              ! Pick The Right Matrix Equation And Solve It
                    if ( nr == n ) then
       ! :))             .. best case, r1 is inverted. the solution of this matrix
                       ! equation is q2*v2 = the product of the jacobi rotations
                       ! used in stdlib_cgesvj, premultiplied with the orthogonal matrix
                       ! from the second qr factorization.
                       call stdlib_ctrsm('L','U','N','N', nr,nr,cone, a,lda, v,ldv)
                    else
                       ! .. r1 is well conditioned, but non-square. adjoint of r2
                       ! is inverted to get the product of the jacobi rotations
                       ! used in stdlib_cgesvj. the q-factor from the second qr
                       ! factorization is then built in explicitly.
                       call stdlib_ctrsm('L','U','C','N',nr,nr,cone,cwork(2_ilp*n+1),n,v,ldv)
                       if ( nr < n ) then
                       call stdlib_claset('A',n-nr,nr,czero,czero,v(nr+1,1_ilp),ldv)
                       call stdlib_claset('A',nr,n-nr,czero,czero,v(1_ilp,nr+1),ldv)
                       call stdlib_claset('A',n-nr,n-nr,czero,cone,v(nr+1,nr+1),ldv)
                       end if
                       call stdlib_cunmqr('L','N',n,n,nr,cwork(2_ilp*n+1),n,cwork(n+1),v,ldv,cwork(&
                                 2_ilp*n+n*nr+nr+1),lwork-2*n-n*nr-nr,ierr)
                    end if
                 else if ( condr2 < cond_ok ) then
                    ! the matrix r2 is inverted. the solution of the matrix equation
                    ! is q3^* * v3 = the product of the jacobi rotations (appplied to
                    ! the lower triangular l3 from the lq factorization of
                    ! r2=l3*q3), pre-multiplied with the transposed q3.
                    call stdlib_cgesvj( 'L', 'U', 'N', nr, nr, v, ldv, sva, nr, u,ldu, cwork(2_ilp*n+&
                              n*nr+nr+1), lwork-2*n-n*nr-nr,rwork, lrwork, info )
                    scalem  = rwork(1_ilp)
                    numrank = nint(rwork(2_ilp),KIND=ilp)
                    do p = 1, nr
                       call stdlib_ccopy( nr, v(1_ilp,p), 1_ilp, u(1_ilp,p), 1_ilp )
                       call stdlib_csscal( nr, sva(p),    u(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_ctrsm('L','U','N','N',nr,nr,cone,cwork(2_ilp*n+1),n,u,ldu)
                    ! Apply The Permutation From The Second Qr Factorization
                    do q = 1, nr
                       do p = 1, nr
                          cwork(2_ilp*n+n*nr+nr+iwork(n+p)) = u(p,q)
                       end do
                       do p = 1, nr
                          u(p,q) = cwork(2_ilp*n+n*nr+nr+p)
                       end do
                    end do
                    if ( nr < n ) then
                       call stdlib_claset( 'A',n-nr,nr,czero,czero,v(nr+1,1_ilp),ldv )
                       call stdlib_claset( 'A',nr,n-nr,czero,czero,v(1_ilp,nr+1),ldv )
                       call stdlib_claset('A',n-nr,n-nr,czero,cone,v(nr+1,nr+1),ldv)
                    end if
                    call stdlib_cunmqr( 'L','N',n,n,nr,cwork(2_ilp*n+1),n,cwork(n+1),v,ldv,cwork(2_ilp*n+&
                              n*nr+nr+1),lwork-2*n-n*nr-nr,ierr )
                 else
                    ! last line of defense.
       ! #:(          this is a rather pathological case: no scaled condition
                    ! improvement after two pivoted qr factorizations. other
                    ! possibility is that the rank revealing qr factorization
                    ! or the condition estimator has failed, or the cond_ok
                    ! is set very close to one (which is unnecessary). normally,
                    ! this branch should never be executed, but in rare cases of
                    ! failure of the rrqr or condition estimator, the last line of
                    ! defense ensures that stdlib_cgejsv completes the task.
                    ! compute the full svd of l3 using stdlib_cgesvj with explicit
                    ! accumulation of jacobi rotations.
                    call stdlib_cgesvj( 'L', 'U', 'V', nr, nr, v, ldv, sva, nr, u,ldu, cwork(2_ilp*n+&
                              n*nr+nr+1), lwork-2*n-n*nr-nr,rwork, lrwork, info )
                    scalem  = rwork(1_ilp)
                    numrank = nint(rwork(2_ilp),KIND=ilp)
                    if ( nr < n ) then
                       call stdlib_claset( 'A',n-nr,nr,czero,czero,v(nr+1,1_ilp),ldv )
                       call stdlib_claset( 'A',nr,n-nr,czero,czero,v(1_ilp,nr+1),ldv )
                       call stdlib_claset('A',n-nr,n-nr,czero,cone,v(nr+1,nr+1),ldv)
                    end if
                    call stdlib_cunmqr( 'L','N',n,n,nr,cwork(2_ilp*n+1),n,cwork(n+1),v,ldv,cwork(2_ilp*n+&
                              n*nr+nr+1),lwork-2*n-n*nr-nr,ierr )
                    call stdlib_cunmlq( 'L', 'C', nr, nr, nr, cwork(2_ilp*n+1), n,cwork(2_ilp*n+n*nr+1), &
                              u, ldu, cwork(2_ilp*n+n*nr+nr+1),lwork-2*n-n*nr-nr, ierr )
                    do q = 1, nr
                       do p = 1, nr
                          cwork(2_ilp*n+n*nr+nr+iwork(n+p)) = u(p,q)
                       end do
                       do p = 1, nr
                          u(p,q) = cwork(2_ilp*n+n*nr+nr+p)
                       end do
                    end do
                 end if
                 ! permute the rows of v using the (column) permutation from the
                 ! first qrf. also, scale the columns to make them unit in
                 ! euclidean norm. this applies to all cases.
                 temp1 = sqrt(real(n,KIND=sp)) * epsln
                 do q = 1, n
                    do p = 1, n
                       cwork(2_ilp*n+n*nr+nr+iwork(p)) = v(p,q)
                    end do
                    do p = 1, n
                       v(p,q) = cwork(2_ilp*n+n*nr+nr+p)
                    end do
                    xsc = one / stdlib_scnrm2( n, v(1_ilp,q), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_csscal( n, xsc,&
                               v(1_ilp,q), 1_ilp )
                 end do
                 ! at this moment, v contains the right singular vectors of a.
                 ! next, assemble the left singular vector matrix u (m x n).
                 if ( nr < m ) then
                    call stdlib_claset('A', m-nr, nr, czero, czero, u(nr+1,1_ilp), ldu)
                    if ( nr < n1 ) then
                       call stdlib_claset('A',nr,n1-nr,czero,czero,u(1_ilp,nr+1),ldu)
                       call stdlib_claset('A',m-nr,n1-nr,czero,cone,u(nr+1,nr+1),ldu)
                    end if
                 end if
                 ! the q matrix from the first qrf is built into the left singular
                 ! matrix u. this applies to all cases.
                 call stdlib_cunmqr( 'L', 'N', m, n1, n, a, lda, cwork, u,ldu, cwork(n+1), lwork-&
                           n, ierr )
                 ! the columns of u are normalized. the cost is o(m*n) flops.
                 temp1 = sqrt(real(m,KIND=sp)) * epsln
                 do p = 1, nr
                    xsc = one / stdlib_scnrm2( m, u(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_csscal( m, xsc,&
                               u(1_ilp,p), 1_ilp )
                 end do
                 ! if the initial qrf is computed with row pivoting, the left
                 ! singular vectors must be adjusted.
                 if ( rowpiv )call stdlib_claswp( n1, u, ldu, 1_ilp, m-1, iwork(iwoff+1), -1_ilp )
              else
              ! The Initial Matrix A Has Almost Orthogonal Columns And
              ! the second qrf is not needed
                 call stdlib_clacpy( 'U', n, n, a, lda, cwork(n+1), n )
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do p = 2, n
                       ctemp = xsc * cwork( n + (p-1)*n + p )
                       do q = 1, p - 1
                           ! cwork(n+(q-1)*n+p)=-temp1 * ( cwork(n+(p-1)*n+q) /
           ! $                                        abs(cwork(n+(p-1)*n+q)) )
                          cwork(n+(q-1)*n+p)=-ctemp
                       end do
                    end do
                 else
                    call stdlib_claset( 'L',n-1,n-1,czero,czero,cwork(n+2),n )
                 end if
                 call stdlib_cgesvj( 'U', 'U', 'N', n, n, cwork(n+1), n, sva,n, u, ldu, cwork(n+&
                           n*n+1), lwork-n-n*n, rwork, lrwork,info )
                 scalem  = rwork(1_ilp)
                 numrank = nint(rwork(2_ilp),KIND=ilp)
                 do p = 1, n
                    call stdlib_ccopy( n, cwork(n+(p-1)*n+1), 1_ilp, u(1_ilp,p), 1_ilp )
                    call stdlib_csscal( n, sva(p), cwork(n+(p-1)*n+1), 1_ilp )
                 end do
                 call stdlib_ctrsm( 'L', 'U', 'N', 'N', n, n,cone, a, lda, cwork(n+1), n )
                 do p = 1, n
                    call stdlib_ccopy( n, cwork(n+p), n, v(iwork(p),1_ilp), ldv )
                 end do
                 temp1 = sqrt(real(n,KIND=sp))*epsln
                 do p = 1, n
                    xsc = one / stdlib_scnrm2( n, v(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_csscal( n, xsc,&
                               v(1_ilp,p), 1_ilp )
                 end do
                 ! assemble the left singular vector matrix u (m x n).
                 if ( n < m ) then
                    call stdlib_claset( 'A',  m-n, n, czero, czero, u(n+1,1_ilp), ldu )
                    if ( n < n1 ) then
                       call stdlib_claset('A',n,  n1-n, czero, czero,  u(1_ilp,n+1),ldu)
                       call stdlib_claset( 'A',m-n,n1-n, czero, cone,u(n+1,n+1),ldu)
                    end if
                 end if
                 call stdlib_cunmqr( 'L', 'N', m, n1, n, a, lda, cwork, u,ldu, cwork(n+1), lwork-&
                           n, ierr )
                 temp1 = sqrt(real(m,KIND=sp))*epsln
                 do p = 1, n1
                    xsc = one / stdlib_scnrm2( m, u(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_csscal( m, xsc,&
                               u(1_ilp,p), 1_ilp )
                 end do
                 if ( rowpiv )call stdlib_claswp( n1, u, ldu, 1_ilp, m-1, iwork(iwoff+1), -1_ilp )
              end if
              ! end of the  >> almost orthogonal case <<  in the full svd
              else
              ! this branch deploys a preconditioned jacobi svd with explicitly
              ! accumulated rotations. it is included as optional, mainly for
              ! experimental purposes. it does perform well, and can also be used.
              ! in this implementation, this branch will be automatically activated
              ! if the  condition number sigma_max(a) / sigma_min(a) is predicted
              ! to be greater than the overflow threshold. this is because the
              ! a posteriori computation of the singular vectors assumes robust
              ! implementation of blas and some lapack procedures, capable of working
              ! in presence of extreme values, e.g. when the singular values spread from
              ! the underflow to the overflow threshold.
              do p = 1, nr
                 call stdlib_ccopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                 call stdlib_clacgv( n-p+1, v(p,p), 1_ilp )
              end do
              if ( l2pert ) then
                 xsc = sqrt(small/epsln)
                 do q = 1, nr
                    ctemp = cmplx(xsc*abs( v(q,q) ),zero,KIND=sp)
                    do p = 1, n
                       if ( ( p > q ) .and. ( abs(v(p,q)) <= temp1 ).or. ( p < q ) )v(p,q) = &
                                 ctemp
           ! $                v(p,q) = temp1 * ( v(p,q) / abs(v(p,q)) )
                       if ( p < q ) v(p,q) = - v(p,q)
                    end do
                 end do
              else
                 if (nr>1_ilp) call stdlib_claset( 'U', nr-1, nr-1, czero, czero, v(1_ilp,2_ilp), ldv )
              end if
              call stdlib_cgeqrf( n, nr, v, ldv, cwork(n+1), cwork(2_ilp*n+1),lwork-2*n, ierr )
                        
              call stdlib_clacpy( 'L', n, nr, v, ldv, cwork(2_ilp*n+1), n )
              do p = 1, nr
                 call stdlib_ccopy( nr-p+1, v(p,p), ldv, u(p,p), 1_ilp )
                 call stdlib_clacgv( nr-p+1, u(p,p), 1_ilp )
              end do
              if ( l2pert ) then
                 xsc = sqrt(small/epsln)
                 do q = 2, nr
                    do p = 1, q - 1
                       ctemp = cmplx(xsc * min(abs(u(p,p)),abs(u(q,q))),zero,KIND=sp)
                        ! u(p,q) = - temp1 * ( u(q,p) / abs(u(q,p)) )
                       u(p,q) = - ctemp
                    end do
                 end do
              else
                 if (nr>1_ilp) call stdlib_claset('U', nr-1, nr-1, czero, czero, u(1_ilp,2_ilp), ldu )
              end if
              call stdlib_cgesvj( 'L', 'U', 'V', nr, nr, u, ldu, sva,n, v, ldv, cwork(2_ilp*n+n*nr+1),&
                         lwork-2*n-n*nr,rwork, lrwork, info )
              scalem  = rwork(1_ilp)
              numrank = nint(rwork(2_ilp),KIND=ilp)
              if ( nr < n ) then
                 call stdlib_claset( 'A',n-nr,nr,czero,czero,v(nr+1,1_ilp),ldv )
                 call stdlib_claset( 'A',nr,n-nr,czero,czero,v(1_ilp,nr+1),ldv )
                 call stdlib_claset( 'A',n-nr,n-nr,czero,cone,v(nr+1,nr+1),ldv )
              end if
              call stdlib_cunmqr( 'L','N',n,n,nr,cwork(2_ilp*n+1),n,cwork(n+1),v,ldv,cwork(2_ilp*n+n*nr+&
                        nr+1),lwork-2*n-n*nr-nr,ierr )
                 ! permute the rows of v using the (column) permutation from the
                 ! first qrf. also, scale the columns to make them unit in
                 ! euclidean norm. this applies to all cases.
                 temp1 = sqrt(real(n,KIND=sp)) * epsln
                 do q = 1, n
                    do p = 1, n
                       cwork(2_ilp*n+n*nr+nr+iwork(p)) = v(p,q)
                    end do
                    do p = 1, n
                       v(p,q) = cwork(2_ilp*n+n*nr+nr+p)
                    end do
                    xsc = one / stdlib_scnrm2( n, v(1_ilp,q), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_csscal( n, xsc,&
                               v(1_ilp,q), 1_ilp )
                 end do
                 ! at this moment, v contains the right singular vectors of a.
                 ! next, assemble the left singular vector matrix u (m x n).
              if ( nr < m ) then
                 call stdlib_claset( 'A',  m-nr, nr, czero, czero, u(nr+1,1_ilp), ldu )
                 if ( nr < n1 ) then
                    call stdlib_claset('A',nr,  n1-nr, czero, czero,  u(1_ilp,nr+1),ldu)
                    call stdlib_claset('A',m-nr,n1-nr, czero, cone,u(nr+1,nr+1),ldu)
                 end if
              end if
              call stdlib_cunmqr( 'L', 'N', m, n1, n, a, lda, cwork, u,ldu, cwork(n+1), lwork-n, &
                        ierr )
                 if ( rowpiv )call stdlib_claswp( n1, u, ldu, 1_ilp, m-1, iwork(iwoff+1), -1_ilp )
              end if
              if ( transp ) then
                 ! .. swap u and v because the procedure worked on a^*
                 do p = 1, n
                    call stdlib_cswap( n, u(1_ilp,p), 1_ilp, v(1_ilp,p), 1_ilp )
                 end do
              end if
           end if
           ! end of the full svd
           ! undo scaling, if necessary (and possible)
           if ( uscal2 <= (big/sva(1_ilp))*uscal1 ) then
              call stdlib_slascl( 'G', 0_ilp, 0_ilp, uscal1, uscal2, nr, 1_ilp, sva, n, ierr )
              uscal1 = one
              uscal2 = one
           end if
           if ( nr < n ) then
              do p = nr+1, n
                 sva(p) = zero
              end do
           end if
           rwork(1_ilp) = uscal2 * scalem
           rwork(2_ilp) = uscal1
           if ( errest ) rwork(3_ilp) = sconda
           if ( lsvec .and. rsvec ) then
              rwork(4_ilp) = condr1
              rwork(5_ilp) = condr2
           end if
           if ( l2tran ) then
              rwork(6_ilp) = entra
              rwork(7_ilp) = entrat
           end if
           iwork(1_ilp) = nr
           iwork(2_ilp) = numrank
           iwork(3_ilp) = warning
           if ( transp ) then
               iwork(4_ilp) =  1_ilp
           else
               iwork(4_ilp) = -1_ilp
           end if
           return
     end subroutine stdlib_cgejsv

     pure module subroutine stdlib_zgejsv( joba, jobu, jobv, jobr, jobt, jobp,m, n, a, lda, sva, u, ldu, &
     !! ZGEJSV computes the singular value decomposition (SVD) of a complex M-by-N
     !! matrix [A], where M >= N. The SVD of [A] is written as
     !! [A] = [U] * [SIGMA] * [V]^*,
     !! where [SIGMA] is an N-by-N (M-by-N) matrix which is zero except for its N
     !! diagonal elements, [U] is an M-by-N (or M-by-M) unitary matrix, and
     !! [V] is an N-by-N unitary matrix. The diagonal elements of [SIGMA] are
     !! the singular values of [A]. The columns of [U] and [V] are the left and
     !! the right singular vectors of [A], respectively. The matrices [U] and [V]
     !! are computed and stored in the arrays U and V, respectively. The diagonal
     !! of [SIGMA] is computed and stored in the array SVA.
               v, ldv,cwork, lwork, rwork, lrwork, iwork, info )
        ! -- lapack computational routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_dp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldu, ldv, lwork, lrwork, m, n
           ! Array Arguments 
           complex(dp), intent(inout) :: a(lda,*)
           complex(dp), intent(out) :: u(ldu,*), v(ldv,*), cwork(lwork)
           real(dp), intent(out) :: sva(n), rwork(lrwork)
           integer(ilp), intent(out) :: iwork(*)
           character, intent(in) :: joba, jobp, jobr, jobt, jobu, jobv
        ! ===========================================================================
           
           
           ! Local Scalars 
           complex(dp) :: ctemp
           real(dp) :: aapp, aaqq, aatmax, aatmin, big, big1, cond_ok, condr1, condr2, entra, &
                     entrat, epsln, maxprj, scalem, sconda, sfmin, small, temp1, uscal1, uscal2, xsc
           integer(ilp) :: ierr, n1, nr, numrank, p, q, warning
           logical(lk) :: almort, defr, errest, goscal, jracc, kill, lquery, lsvec, l2aber, &
                     l2kill, l2pert, l2rank, l2tran, noscal, rowpiv, rsvec, transp
           integer(ilp) :: optwrk, minwrk, minrwrk, miniwrk
           integer(ilp) :: lwcon, lwlqf, lwqp3, lwqrf, lwunmlq, lwunmqr, lwunmqrm, lwsvdj, &
                     lwsvdjv, lrwqp3, lrwcon, lrwsvdj, iwoff
           integer(ilp) :: lwrk_zgelqf, lwrk_zgeqp3, lwrk_zgeqp3n, lwrk_zgeqrf, lwrk_zgesvj, &
                     lwrk_zgesvjv, lwrk_zgesvju, lwrk_zunmlq, lwrk_zunmqr, lwrk_zunmqrm
           ! Local Arrays
           complex(dp) :: cdummy(1_ilp)
           real(dp) :: rdummy(1_ilp)
           ! Intrinsic Functions 
           ! test the input arguments
           lsvec  = stdlib_lsame( jobu, 'U' ) .or. stdlib_lsame( jobu, 'F' )
           jracc  = stdlib_lsame( jobv, 'J' )
           rsvec  = stdlib_lsame( jobv, 'V' ) .or. jracc
           rowpiv = stdlib_lsame( joba, 'F' ) .or. stdlib_lsame( joba, 'G' )
           l2rank = stdlib_lsame( joba, 'R' )
           l2aber = stdlib_lsame( joba, 'A' )
           errest = stdlib_lsame( joba, 'E' ) .or. stdlib_lsame( joba, 'G' )
           l2tran = stdlib_lsame( jobt, 'T' ) .and. ( m == n )
           l2kill = stdlib_lsame( jobr, 'R' )
           defr   = stdlib_lsame( jobr, 'N' )
           l2pert = stdlib_lsame( jobp, 'P' )
           lquery = ( lwork == -1_ilp ) .or. ( lrwork == -1_ilp )
           if ( .not.(rowpiv .or. l2rank .or. l2aber .or.errest .or. stdlib_lsame( joba, 'C' ) )) &
                     then
              info = - 1_ilp
           else if ( .not.( lsvec .or. stdlib_lsame( jobu, 'N' ) .or.( stdlib_lsame( jobu, 'W' ) &
                     .and. rsvec .and. l2tran ) ) ) then
              info = - 2_ilp
           else if ( .not.( rsvec .or. stdlib_lsame( jobv, 'N' ) .or.( stdlib_lsame( jobv, 'W' ) &
                     .and. lsvec .and. l2tran ) ) ) then
              info = - 3_ilp
           else if ( .not. ( l2kill .or. defr ) )    then
              info = - 4_ilp
           else if ( .not. ( stdlib_lsame(jobt,'T') .or. stdlib_lsame(jobt,'N') ) ) then
              info = - 5_ilp
           else if ( .not. ( l2pert .or. stdlib_lsame( jobp, 'N' ) ) ) then
              info = - 6_ilp
           else if ( m < 0_ilp ) then
              info = - 7_ilp
           else if ( ( n < 0_ilp ) .or. ( n > m ) ) then
              info = - 8_ilp
           else if ( lda < m ) then
              info = - 10_ilp
           else if ( lsvec .and. ( ldu < m ) ) then
              info = - 13_ilp
           else if ( rsvec .and. ( ldv < n ) ) then
              info = - 15_ilp
           else
              ! #:)
              info = 0_ilp
           end if
           if ( info == 0_ilp ) then
               ! Compute The Minimal And The Optimal Workspace Lengths
               ! [[the expressions for computing the minimal and the optimal
               ! values of lcwork, lrwork are written with a lot of redundancy and
               ! can be simplified. however, this verbose form is useful for
               ! maintenance and modifications of the code.]]
              ! .. minimal workspace length for stdlib_zgeqp3 of an m x n matrix,
               ! stdlib_zgeqrf of an n x n matrix, stdlib_zgelqf of an n x n matrix,
               ! stdlib_zunmlq for computing n x n matrix, stdlib_zunmqr for computing n x n
               ! matrix, stdlib_zunmqr for computing m x n matrix, respectively.
               lwqp3 = n+1
               lwqrf = max( 1_ilp, n )
               lwlqf = max( 1_ilp, n )
               lwunmlq  = max( 1_ilp, n )
               lwunmqr  = max( 1_ilp, n )
               lwunmqrm = max( 1_ilp, m )
              ! Minimal Workspace Length For Stdlib_Zpocon Of An N X N Matrix
               lwcon = 2_ilp * n
              ! .. minimal workspace length for stdlib_zgesvj of an n x n matrix,
               ! without and with explicit accumulation of jacobi rotations
               lwsvdj  = max( 2_ilp * n, 1_ilp )
               lwsvdjv = max( 2_ilp * n, 1_ilp )
               ! .. minimal real workspace length for stdlib_zgeqp3, stdlib_zpocon, stdlib_zgesvj
               lrwqp3  = 2_ilp * n
               lrwcon  = n
               lrwsvdj = n
               if ( lquery ) then
                   call stdlib_zgeqp3( m, n, a, lda, iwork, cdummy, cdummy, -1_ilp,rdummy, ierr )
                             
                   lwrk_zgeqp3 = real( cdummy(1_ilp),KIND=dp)
                   call stdlib_zgeqrf( n, n, a, lda, cdummy, cdummy,-1_ilp, ierr )
                   lwrk_zgeqrf = real( cdummy(1_ilp),KIND=dp)
                   call stdlib_zgelqf( n, n, a, lda, cdummy, cdummy,-1_ilp, ierr )
                   lwrk_zgelqf = real( cdummy(1_ilp),KIND=dp)
               end if
               minwrk  = 2_ilp
               optwrk  = 2_ilp
               miniwrk = n
               if ( .not. (lsvec .or. rsvec ) ) then
                   ! Minimal And Optimal Sizes Of The Complex Workspace If
                   ! only the singular values are requested
                   if ( errest ) then
                       minwrk = max( n+lwqp3, n**2_ilp+lwcon, n+lwqrf, lwsvdj )
                   else
                       minwrk = max( n+lwqp3, n+lwqrf, lwsvdj )
                   end if
                   if ( lquery ) then
                       call stdlib_zgesvj( 'L', 'N', 'N', n, n, a, lda, sva, n, v,ldv, cdummy, -1_ilp,&
                                  rdummy, -1_ilp, ierr )
                       lwrk_zgesvj = real( cdummy(1_ilp),KIND=dp)
                       if ( errest ) then
                           optwrk = max( n+lwrk_zgeqp3, n**2_ilp+lwcon,n+lwrk_zgeqrf, lwrk_zgesvj )
                                     
                       else
                           optwrk = max( n+lwrk_zgeqp3, n+lwrk_zgeqrf,lwrk_zgesvj )
                       end if
                   end if
                   if ( l2tran .or. rowpiv ) then
                       if ( errest ) then
                          minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwcon, lrwsvdj )
                       else
                          minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj )
                       end if
                   else
                       if ( errest ) then
                          minrwrk = max( 7_ilp, lrwqp3, lrwcon, lrwsvdj )
                       else
                          minrwrk = max( 7_ilp, lrwqp3, lrwsvdj )
                       end if
                   end if
                   if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
               else if ( rsvec .and. (.not.lsvec) ) then
                  ! Minimal And Optimal Sizes Of The Complex Workspace If The
                  ! singular values and the right singular vectors are requested
                  if ( errest ) then
                      minwrk = max( n+lwqp3, lwcon, lwsvdj, n+lwlqf,2_ilp*n+lwqrf, n+lwsvdj, n+&
                                lwunmlq )
                  else
                      minwrk = max( n+lwqp3, lwsvdj, n+lwlqf, 2_ilp*n+lwqrf,n+lwsvdj, n+lwunmlq )
                                
                  end if
                  if ( lquery ) then
                      call stdlib_zgesvj( 'L', 'U', 'N', n,n, u, ldu, sva, n, a,lda, cdummy, -1_ilp, &
                                rdummy, -1_ilp, ierr )
                      lwrk_zgesvj = real( cdummy(1_ilp),KIND=dp)
                      call stdlib_zunmlq( 'L', 'C', n, n, n, a, lda, cdummy,v, ldv, cdummy, -1_ilp, &
                                ierr )
                      lwrk_zunmlq = real( cdummy(1_ilp),KIND=dp)
                      if ( errest ) then
                      optwrk = max( n+lwrk_zgeqp3, lwcon, lwrk_zgesvj,n+lwrk_zgelqf, 2_ilp*n+&
                                lwrk_zgeqrf,n+lwrk_zgesvj,  n+lwrk_zunmlq )
                      else
                      optwrk = max( n+lwrk_zgeqp3, lwrk_zgesvj,n+lwrk_zgelqf,2_ilp*n+lwrk_zgeqrf, n+&
                                lwrk_zgesvj,n+lwrk_zunmlq )
                      end if
                  end if
                  if ( l2tran .or. rowpiv ) then
                       if ( errest ) then
                          minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj, lrwcon )
                       else
                          minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj )
                       end if
                  else
                       if ( errest ) then
                          minrwrk = max( 7_ilp, lrwqp3, lrwsvdj, lrwcon )
                       else
                          minrwrk = max( 7_ilp, lrwqp3, lrwsvdj )
                       end if
                  end if
                  if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
               else if ( lsvec .and. (.not.rsvec) ) then
                  ! Minimal And Optimal Sizes Of The Complex Workspace If The
                  ! singular values and the left singular vectors are requested
                  if ( errest ) then
                      minwrk = n + max( lwqp3,lwcon,n+lwqrf,lwsvdj,lwunmqrm )
                  else
                      minwrk = n + max( lwqp3, n+lwqrf, lwsvdj, lwunmqrm )
                  end if
                  if ( lquery ) then
                      call stdlib_zgesvj( 'L', 'U', 'N', n,n, u, ldu, sva, n, a,lda, cdummy, -1_ilp, &
                                rdummy, -1_ilp, ierr )
                      lwrk_zgesvj = real( cdummy(1_ilp),KIND=dp)
                      call stdlib_zunmqr( 'L', 'N', m, n, n, a, lda, cdummy, u,ldu, cdummy, -1_ilp, &
                                ierr )
                      lwrk_zunmqrm = real( cdummy(1_ilp),KIND=dp)
                      if ( errest ) then
                      optwrk = n + max( lwrk_zgeqp3, lwcon, n+lwrk_zgeqrf,lwrk_zgesvj, &
                                lwrk_zunmqrm )
                      else
                      optwrk = n + max( lwrk_zgeqp3, n+lwrk_zgeqrf,lwrk_zgesvj, lwrk_zunmqrm )
                                
                      end if
                  end if
                  if ( l2tran .or. rowpiv ) then
                      if ( errest ) then
                         minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj, lrwcon )
                      else
                         minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj )
                      end if
                  else
                      if ( errest ) then
                         minrwrk = max( 7_ilp, lrwqp3, lrwsvdj, lrwcon )
                      else
                         minrwrk = max( 7_ilp, lrwqp3, lrwsvdj )
                      end if
                  end if
                  if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
               else
                  ! Minimal And Optimal Sizes Of The Complex Workspace If The
                  ! full svd is requested
                  if ( .not. jracc ) then
                      if ( errest ) then
                         minwrk = max( n+lwqp3, n+lwcon,  2_ilp*n+n**2_ilp+lwcon,2_ilp*n+lwqrf,         2_ilp*n+&
                         lwqp3,2_ilp*n+n**2_ilp+n+lwlqf,  2_ilp*n+n**2_ilp+n+n**2_ilp+lwcon,2_ilp*n+n**2_ilp+n+lwsvdj, 2_ilp*n+&
                         n**2_ilp+n+lwsvdjv,2_ilp*n+n**2_ilp+n+lwunmqr,2_ilp*n+n**2_ilp+n+lwunmlq,n+n**2_ilp+lwsvdj,   n+&
                                   lwunmqrm )
                      else
                         minwrk = max( n+lwqp3,        2_ilp*n+n**2_ilp+lwcon,2_ilp*n+lwqrf,         2_ilp*n+&
                         lwqp3,2_ilp*n+n**2_ilp+n+lwlqf,  2_ilp*n+n**2_ilp+n+n**2_ilp+lwcon,2_ilp*n+n**2_ilp+n+lwsvdj, 2_ilp*n+&
                         n**2_ilp+n+lwsvdjv,2_ilp*n+n**2_ilp+n+lwunmqr,2_ilp*n+n**2_ilp+n+lwunmlq,n+n**2_ilp+lwsvdj,      &
                                   n+lwunmqrm )
                      end if
                      miniwrk = miniwrk + n
                      if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
                  else
                      if ( errest ) then
                         minwrk = max( n+lwqp3, n+lwcon, 2_ilp*n+lwqrf,2_ilp*n+n**2_ilp+lwsvdjv, 2_ilp*n+n**2_ilp+n+&
                                   lwunmqr,n+lwunmqrm )
                      else
                         minwrk = max( n+lwqp3, 2_ilp*n+lwqrf,2_ilp*n+n**2_ilp+lwsvdjv, 2_ilp*n+n**2_ilp+n+lwunmqr,n+&
                                   lwunmqrm )
                      end if
                      if ( rowpiv .or. l2tran ) miniwrk = miniwrk + m
                  end if
                  if ( lquery ) then
                      call stdlib_zunmqr( 'L', 'N', m, n, n, a, lda, cdummy, u,ldu, cdummy, -1_ilp, &
                                ierr )
                      lwrk_zunmqrm = real( cdummy(1_ilp),KIND=dp)
                      call stdlib_zunmqr( 'L', 'N', n, n, n, a, lda, cdummy, u,ldu, cdummy, -1_ilp, &
                                ierr )
                      lwrk_zunmqr = real( cdummy(1_ilp),KIND=dp)
                      if ( .not. jracc ) then
                          call stdlib_zgeqp3( n,n, a, lda, iwork, cdummy,cdummy, -1_ilp,rdummy, ierr )
                                    
                          lwrk_zgeqp3n = real( cdummy(1_ilp),KIND=dp)
                          call stdlib_zgesvj( 'L', 'U', 'N', n, n, u, ldu, sva,n, v, ldv, cdummy, &
                                    -1_ilp, rdummy, -1_ilp, ierr )
                          lwrk_zgesvj = real( cdummy(1_ilp),KIND=dp)
                          call stdlib_zgesvj( 'U', 'U', 'N', n, n, u, ldu, sva,n, v, ldv, cdummy, &
                                    -1_ilp, rdummy, -1_ilp, ierr )
                          lwrk_zgesvju = real( cdummy(1_ilp),KIND=dp)
                          call stdlib_zgesvj( 'L', 'U', 'V', n, n, u, ldu, sva,n, v, ldv, cdummy, &
                                    -1_ilp, rdummy, -1_ilp, ierr )
                          lwrk_zgesvjv = real( cdummy(1_ilp),KIND=dp)
                          call stdlib_zunmlq( 'L', 'C', n, n, n, a, lda, cdummy,v, ldv, cdummy, -&
                                    1_ilp, ierr )
                          lwrk_zunmlq = real( cdummy(1_ilp),KIND=dp)
                          if ( errest ) then
                            optwrk = max( n+lwrk_zgeqp3, n+lwcon,2_ilp*n+n**2_ilp+lwcon, 2_ilp*n+lwrk_zgeqrf,&
                            2_ilp*n+lwrk_zgeqp3n,2_ilp*n+n**2_ilp+n+lwrk_zgelqf,2_ilp*n+n**2_ilp+n+n**2_ilp+lwcon,2_ilp*n+&
                            n**2_ilp+n+lwrk_zgesvj,2_ilp*n+n**2_ilp+n+lwrk_zgesvjv,2_ilp*n+n**2_ilp+n+lwrk_zunmqr,2_ilp*n+&
                                      n**2_ilp+n+lwrk_zunmlq,n+n**2_ilp+lwrk_zgesvju,n+lwrk_zunmqrm )
                          else
                            optwrk = max( n+lwrk_zgeqp3,2_ilp*n+n**2_ilp+lwcon, 2_ilp*n+lwrk_zgeqrf,2_ilp*n+&
                            lwrk_zgeqp3n,2_ilp*n+n**2_ilp+n+lwrk_zgelqf,2_ilp*n+n**2_ilp+n+n**2_ilp+lwcon,2_ilp*n+n**2_ilp+n+&
                            lwrk_zgesvj,2_ilp*n+n**2_ilp+n+lwrk_zgesvjv,2_ilp*n+n**2_ilp+n+lwrk_zunmqr,2_ilp*n+n**2_ilp+n+&
                                      lwrk_zunmlq,n+n**2_ilp+lwrk_zgesvju,n+lwrk_zunmqrm )
                          end if
                      else
                          call stdlib_zgesvj( 'L', 'U', 'V', n, n, u, ldu, sva,n, v, ldv, cdummy, &
                                    -1_ilp, rdummy, -1_ilp, ierr )
                          lwrk_zgesvjv = real( cdummy(1_ilp),KIND=dp)
                          call stdlib_zunmqr( 'L', 'N', n, n, n, cdummy, n, cdummy,v, ldv, cdummy,&
                                     -1_ilp, ierr )
                          lwrk_zunmqr = real( cdummy(1_ilp),KIND=dp)
                          call stdlib_zunmqr( 'L', 'N', m, n, n, a, lda, cdummy, u,ldu, cdummy, -&
                                    1_ilp, ierr )
                          lwrk_zunmqrm = real( cdummy(1_ilp),KIND=dp)
                          if ( errest ) then
                             optwrk = max( n+lwrk_zgeqp3, n+lwcon,2_ilp*n+lwrk_zgeqrf, 2_ilp*n+n**2_ilp,2_ilp*n+&
                                       n**2_ilp+lwrk_zgesvjv,2_ilp*n+n**2_ilp+n+lwrk_zunmqr,n+lwrk_zunmqrm )
                          else
                             optwrk = max( n+lwrk_zgeqp3, 2_ilp*n+lwrk_zgeqrf,2_ilp*n+n**2_ilp, 2_ilp*n+n**2_ilp+&
                                       lwrk_zgesvjv,2_ilp*n+n**2_ilp+n+lwrk_zunmqr,n+lwrk_zunmqrm )
                          end if
                      end if
                  end if
                  if ( l2tran .or. rowpiv ) then
                      minrwrk = max( 7_ilp, 2_ilp*m,  lrwqp3, lrwsvdj, lrwcon )
                  else
                      minrwrk = max( 7_ilp, lrwqp3, lrwsvdj, lrwcon )
                  end if
               end if
               minwrk = max( 2_ilp, minwrk )
               optwrk = max( minwrk, optwrk )
               if ( lwork  < minwrk  .and. (.not.lquery) ) info = - 17_ilp
               if ( lrwork < minrwrk .and. (.not.lquery) ) info = - 19_ilp
           end if
           if ( info /= 0_ilp ) then
             ! #:(
              call stdlib_xerbla( 'ZGEJSV', - info )
              return
           else if ( lquery ) then
               cwork(1_ilp) = optwrk
               cwork(2_ilp) = minwrk
               rwork(1_ilp) = minrwrk
               iwork(1_ilp) = max( 4_ilp, miniwrk )
               return
           end if
           ! quick return for void matrix (y3k safe)
       ! #:)
           if ( ( m == 0_ilp ) .or. ( n == 0_ilp ) ) then
              iwork(1_ilp:4_ilp) = 0_ilp
              rwork(1_ilp:7_ilp) = 0_ilp
              return
           endif
           ! determine whether the matrix u should be m x n or m x m
           if ( lsvec ) then
              n1 = n
              if ( stdlib_lsame( jobu, 'F' ) ) n1 = m
           end if
           ! set numerical parameters
      ! !    note: make sure stdlib_dlamch() does not fail on the target architecture.
           epsln = stdlib_dlamch('EPSILON')
           sfmin = stdlib_dlamch('SAFEMINIMUM')
           small = sfmin / epsln
           big   = stdlib_dlamch('O')
           ! big   = one / sfmin
           ! initialize sva(1:n) = diag( ||a e_i||_2 )_1^n
      ! (!)  if necessary, scale sva() to protect the largest norm from
           ! overflow. it is possible that this scaling pushes the smallest
           ! column norm left from the underflow threshold (extreme case).
           scalem  = one / sqrt(real(m,KIND=dp)*real(n,KIND=dp))
           noscal  = .true.
           goscal  = .true.
           do p = 1, n
              aapp = zero
              aaqq = one
              call stdlib_zlassq( m, a(1_ilp,p), 1_ilp, aapp, aaqq )
              if ( aapp > big ) then
                 info = - 9_ilp
                 call stdlib_xerbla( 'ZGEJSV', -info )
                 return
              end if
              aaqq = sqrt(aaqq)
              if ( ( aapp < (big / aaqq) ) .and. noscal  ) then
                 sva(p)  = aapp * aaqq
              else
                 noscal  = .false.
                 sva(p)  = aapp * ( aaqq * scalem )
                 if ( goscal ) then
                    goscal = .false.
                    call stdlib_dscal( p-1, scalem, sva, 1_ilp )
                 end if
              end if
           end do
           if ( noscal ) scalem = one
           aapp = zero
           aaqq = big
           do p = 1, n
              aapp = max( aapp, sva(p) )
              if ( sva(p) /= zero ) aaqq = min( aaqq, sva(p) )
           end do
           ! quick return for zero m x n matrix
       ! #:)
           if ( aapp == zero ) then
              if ( lsvec ) call stdlib_zlaset( 'G', m, n1, czero, cone, u, ldu )
              if ( rsvec ) call stdlib_zlaset( 'G', n, n,  czero, cone, v, ldv )
              rwork(1_ilp) = one
              rwork(2_ilp) = one
              if ( errest ) rwork(3_ilp) = one
              if ( lsvec .and. rsvec ) then
                 rwork(4_ilp) = one
                 rwork(5_ilp) = one
              end if
              if ( l2tran ) then
                 rwork(6_ilp) = zero
                 rwork(7_ilp) = zero
              end if
              iwork(1_ilp) = 0_ilp
              iwork(2_ilp) = 0_ilp
              iwork(3_ilp) = 0_ilp
              iwork(4_ilp) = -1_ilp
              return
           end if
           ! issue warning if denormalized column norms detected. override the
           ! high relative accuracy request. issue licence to kill nonzero columns
           ! (set them to zero) whose norm is less than sigma_max / big (roughly).
       ! #:(
           warning = 0_ilp
           if ( aaqq <= sfmin ) then
              l2rank = .true.
              l2kill = .true.
              warning = 1_ilp
           end if
           ! quick return for one-column matrix
       ! #:)
           if ( n == 1_ilp ) then
              if ( lsvec ) then
                 call stdlib_zlascl( 'G',0_ilp,0_ilp,sva(1_ilp),scalem, m,1_ilp,a(1_ilp,1_ilp),lda,ierr )
                 call stdlib_zlacpy( 'A', m, 1_ilp, a, lda, u, ldu )
                 ! computing all m left singular vectors of the m x 1 matrix
                 if ( n1 /= n  ) then
                   call stdlib_zgeqrf( m, n, u,ldu, cwork, cwork(n+1),lwork-n,ierr )
                   call stdlib_zungqr( m,n1,1_ilp, u,ldu,cwork,cwork(n+1),lwork-n,ierr )
                   call stdlib_zcopy( m, a(1_ilp,1_ilp), 1_ilp, u(1_ilp,1_ilp), 1_ilp )
                 end if
              end if
              if ( rsvec ) then
                  v(1_ilp,1_ilp) = cone
              end if
              if ( sva(1_ilp) < (big*scalem) ) then
                 sva(1_ilp)  = sva(1_ilp) / scalem
                 scalem  = one
              end if
              rwork(1_ilp) = one / scalem
              rwork(2_ilp) = one
              if ( sva(1_ilp) /= zero ) then
                 iwork(1_ilp) = 1_ilp
                 if ( ( sva(1_ilp) / scalem) >= sfmin ) then
                    iwork(2_ilp) = 1_ilp
                 else
                    iwork(2_ilp) = 0_ilp
                 end if
              else
                 iwork(1_ilp) = 0_ilp
                 iwork(2_ilp) = 0_ilp
              end if
              iwork(3_ilp) = 0_ilp
              iwork(4_ilp) = -1_ilp
              if ( errest ) rwork(3_ilp) = one
              if ( lsvec .and. rsvec ) then
                 rwork(4_ilp) = one
                 rwork(5_ilp) = one
              end if
              if ( l2tran ) then
                 rwork(6_ilp) = zero
                 rwork(7_ilp) = zero
              end if
              return
           end if
           transp = .false.
           aatmax = -one
           aatmin =  big
           if ( rowpiv .or. l2tran ) then
           ! compute the row norms, needed to determine row pivoting sequence
           ! (in the case of heavily row weighted a, row pivoting is strongly
           ! advised) and to collect information needed to compare the
           ! structures of a * a^* and a^* * a (in the case l2tran==.true.).
              if ( l2tran ) then
                 do p = 1, m
                    xsc   = zero
                    temp1 = one
                    call stdlib_zlassq( n, a(p,1_ilp), lda, xsc, temp1 )
                    ! stdlib_zlassq gets both the ell_2 and the ell_infinity norm
                    ! in one pass through the vector
                    rwork(m+p)  = xsc * scalem
                    rwork(p)    = xsc * (scalem*sqrt(temp1))
                    aatmax = max( aatmax, rwork(p) )
                    if (rwork(p) /= zero)aatmin = min(aatmin,rwork(p))
                 end do
              else
                 do p = 1, m
                    rwork(m+p) = scalem*abs( a(p,stdlib_izamax(n,a(p,1_ilp),lda)) )
                    aatmax = max( aatmax, rwork(m+p) )
                    aatmin = min( aatmin, rwork(m+p) )
                 end do
              end if
           end if
           ! for square matrix a try to determine whether a^*  would be better
           ! input for the preconditioned jacobi svd, with faster convergence.
           ! the decision is based on an o(n) function of the vector of column
           ! and row norms of a, based on the shannon entropy. this should give
           ! the right choice in most cases when the difference actually matters.
           ! it may fail and pick the slower converging side.
           entra  = zero
           entrat = zero
           if ( l2tran ) then
              xsc   = zero
              temp1 = one
              call stdlib_dlassq( n, sva, 1_ilp, xsc, temp1 )
              temp1 = one / temp1
              entra = zero
              do p = 1, n
                 big1  = ( ( sva(p) / xsc )**2_ilp ) * temp1
                 if ( big1 /= zero ) entra = entra + big1 * log(big1)
              end do
              entra = - entra / log(real(n,KIND=dp))
              ! now, sva().^2/trace(a^* * a) is a point in the probability simplex.
              ! it is derived from the diagonal of  a^* * a.  do the same with the
              ! diagonal of a * a^*, compute the entropy of the corresponding
              ! probability distribution. note that a * a^* and a^* * a have the
              ! same trace.
              entrat = zero
              do p = 1, m
                 big1 = ( ( rwork(p) / xsc )**2_ilp ) * temp1
                 if ( big1 /= zero ) entrat = entrat + big1 * log(big1)
              end do
              entrat = - entrat / log(real(m,KIND=dp))
              ! analyze the entropies and decide a or a^*. smaller entropy
              ! usually means better input for the algorithm.
              transp = ( entrat < entra )
              ! if a^* is better than a, take the adjoint of a. this is allowed
              ! only for square matrices, m=n.
              if ( transp ) then
                 ! in an optimal implementation, this trivial transpose
                 ! should be replaced with faster transpose.
                 do p = 1, n - 1
                    a(p,p) = conjg(a(p,p))
                    do q = p + 1, n
                        ctemp = conjg(a(q,p))
                       a(q,p) = conjg(a(p,q))
                       a(p,q) = ctemp
                    end do
                 end do
                 a(n,n) = conjg(a(n,n))
                 do p = 1, n
                    rwork(m+p) = sva(p)
                    sva(p)     = rwork(p)
                    ! previously computed row 2-norms are now column 2-norms
                    ! of the transposed matrix
                 end do
                 temp1  = aapp
                 aapp   = aatmax
                 aatmax = temp1
                 temp1  = aaqq
                 aaqq   = aatmin
                 aatmin = temp1
                 kill   = lsvec
                 lsvec  = rsvec
                 rsvec  = kill
                 if ( lsvec ) n1 = n
                 rowpiv = .true.
              end if
           end if
           ! end if l2tran
           ! scale the matrix so that its maximal singular value remains less
           ! than sqrt(big) -- the matrix is scaled so that its maximal column
           ! has euclidean norm equal to sqrt(big/n). the only reason to keep
           ! sqrt(big) instead of big is the fact that stdlib_zgejsv uses lapack and
           ! blas routines that, in some implementations, are not capable of
           ! working in the full interval [sfmin,big] and that they may provoke
           ! overflows in the intermediate results. if the singular values spread
           ! from sfmin to big, then stdlib_zgesvj will compute them. so, in that case,
           ! one should use stdlib_zgesvj instead of stdlib_zgejsv.
           ! >> change in the april 2016 update: allow bigger range, i.e. the
           ! largest column is allowed up to big/n and stdlib_zgesvj will do the rest.
           big1   = sqrt( big )
           temp1  = sqrt( big / real(n,KIND=dp) )
            ! temp1  = big/real(n,KIND=dp)
           call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aapp, temp1, n, 1_ilp, sva, n, ierr )
           if ( aaqq > (aapp * sfmin) ) then
               aaqq = ( aaqq / aapp ) * temp1
           else
               aaqq = ( aaqq * temp1 ) / aapp
           end if
           temp1 = temp1 * scalem
           call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aapp, temp1, m, n, a, lda, ierr )
           ! to undo scaling at the end of this procedure, multiply the
           ! computed singular values with uscal2 / uscal1.
           uscal1 = temp1
           uscal2 = aapp
           if ( l2kill ) then
              ! l2kill enforces computation of nonzero singular values in
              ! the restricted range of condition number of the initial a,
              ! sigma_max(a) / sigma_min(a) approx. sqrt(big)/sqrt(sfmin).
              xsc = sqrt( sfmin )
           else
              xsc = small
              ! now, if the condition number of a is too big,
              ! sigma_max(a) / sigma_min(a) > sqrt(big/n) * epsln / sfmin,
              ! as a precaution measure, the full svd is computed using stdlib_zgesvj
              ! with accumulated jacobi rotations. this provides numerically
              ! more robust computation, at the cost of slightly increased run
              ! time. depending on the concrete implementation of blas and lapack
              ! (i.e. how they behave in presence of extreme ill-conditioning) the
              ! implementor may decide to remove this switch.
              if ( ( aaqq<sqrt(sfmin) ) .and. lsvec .and. rsvec ) then
                 jracc = .true.
              end if
           end if
           if ( aaqq < xsc ) then
              do p = 1, n
                 if ( sva(p) < xsc ) then
                    call stdlib_zlaset( 'A', m, 1_ilp, czero, czero, a(1_ilp,p), lda )
                    sva(p) = zero
                 end if
              end do
           end if
           ! preconditioning using qr factorization with pivoting
           if ( rowpiv ) then
              ! optional row permutation (bjoerck row pivoting):
              ! a result by cox and higham shows that the bjoerck's
              ! row pivoting combined with standard column pivoting
              ! has similar effect as powell-reid complete pivoting.
              ! the ell-infinity norms of a are made nonincreasing.
              if ( ( lsvec .and. rsvec ) .and. .not.( jracc ) ) then
                   iwoff = 2_ilp*n
              else
                   iwoff = n
              end if
              do p = 1, m - 1
                 q = stdlib_idamax( m-p+1, rwork(m+p), 1_ilp ) + p - 1_ilp
                 iwork(iwoff+p) = q
                 if ( p /= q ) then
                    temp1      = rwork(m+p)
                    rwork(m+p) = rwork(m+q)
                    rwork(m+q) = temp1
                 end if
              end do
              call stdlib_zlaswp( n, a, lda, 1_ilp, m-1, iwork(iwoff+1), 1_ilp )
           end if
           ! end of the preparation phase (scaling, optional sorting and
           ! transposing, optional flushing of small columns).
           ! preconditioning
           ! if the full svd is needed, the right singular vectors are computed
           ! from a matrix equation, and for that we need theoretical analysis
           ! of the businger-golub pivoting. so we use stdlib_zgeqp3 as the first rr qrf.
           ! in all other cases the first rr qrf can be chosen by other criteria
           ! (eg speed by replacing global with restricted window pivoting, such
           ! as in xgeqpx from toms # 782). good results will be obtained using
           ! xgeqpx with properly (!) chosen numerical parameters.
           ! any improvement of stdlib_zgeqp3 improves overall performance of stdlib_zgejsv.
           ! a * p1 = q1 * [ r1^* 0]^*:
           do p = 1, n
              ! All Columns Are Free Columns
              iwork(p) = 0_ilp
           end do
           call stdlib_zgeqp3( m, n, a, lda, iwork, cwork, cwork(n+1), lwork-n,rwork, ierr )
                     
           ! the upper triangular matrix r1 from the first qrf is inspected for
           ! rank deficiency and possibilities for deflation, or possible
           ! ill-conditioning. depending on the user specified flag l2rank,
           ! the procedure explores possibilities to reduce the numerical
           ! rank by inspecting the computed upper triangular factor. if
           ! l2rank or l2aber are up, then stdlib_zgejsv will compute the svd of
           ! a + da, where ||da|| <= f(m,n)*epsln.
           nr = 1_ilp
           if ( l2aber ) then
              ! standard absolute error bound suffices. all sigma_i with
              ! sigma_i < n*epsln*||a|| are flushed to zero. this is an
              ! aggressive enforcement of lower numerical rank by introducing a
              ! backward error of the order of n*epsln*||a||.
              temp1 = sqrt(real(n,KIND=dp))*epsln
              loop_3002: do p = 2, n
                 if ( abs(a(p,p)) >= (temp1*abs(a(1_ilp,1_ilp))) ) then
                    nr = nr + 1_ilp
                 else
                    exit loop_3002
                 end if
              end do loop_3002
           else if ( l2rank ) then
              ! .. similarly as above, only slightly more gentle (less aggressive).
              ! sudden drop on the diagonal of r1 is used as the criterion for
              ! close-to-rank-deficient.
              temp1 = sqrt(sfmin)
              loop_3402: do p = 2, n
                 if ( ( abs(a(p,p)) < (epsln*abs(a(p-1,p-1))) ) .or.( abs(a(p,p)) < small ) .or.( &
                           l2kill .and. (abs(a(p,p)) < temp1) ) ) exit loop_3402
                 nr = nr + 1_ilp
              end do loop_3402
           else
              ! the goal is high relative accuracy. however, if the matrix
              ! has high scaled condition number the relative accuracy is in
              ! general not feasible. later on, a condition number estimator
              ! will be deployed to estimate the scaled condition number.
              ! here we just remove the underflowed part of the triangular
              ! factor. this prevents the situation in which the code is
              ! working hard to get the accuracy not warranted by the data.
              temp1  = sqrt(sfmin)
              loop_3302: do p = 2, n
                 if ( ( abs(a(p,p)) < small ) .or.( l2kill .and. (abs(a(p,p)) < temp1) ) ) exit loop_3302
                 nr = nr + 1_ilp
              end do loop_3302
           end if
           almort = .false.
           if ( nr == n ) then
              maxprj = one
              do p = 2, n
                 temp1  = abs(a(p,p)) / sva(iwork(p))
                 maxprj = min( maxprj, temp1 )
              end do
              if ( maxprj**2_ilp >= one - real(n,KIND=dp)*epsln ) almort = .true.
           end if
           sconda = - one
           condr1 = - one
           condr2 = - one
           if ( errest ) then
              if ( n == nr ) then
                 if ( rsvec ) then
                    ! V Is Available As Workspace
                    call stdlib_zlacpy( 'U', n, n, a, lda, v, ldv )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_zdscal( p, one/temp1, v(1_ilp,p), 1_ilp )
                    end do
                    if ( lsvec )then
                        call stdlib_zpocon( 'U', n, v, ldv, one, temp1,cwork(n+1), rwork, ierr )
                                  
                    else
                        call stdlib_zpocon( 'U', n, v, ldv, one, temp1,cwork, rwork, ierr )
                                  
                    end if
                 else if ( lsvec ) then
                    ! U Is Available As Workspace
                    call stdlib_zlacpy( 'U', n, n, a, lda, u, ldu )
                    do p = 1, n
                       temp1 = sva(iwork(p))
                       call stdlib_zdscal( p, one/temp1, u(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_zpocon( 'U', n, u, ldu, one, temp1,cwork(n+1), rwork, ierr )
                              
                 else
                    call stdlib_zlacpy( 'U', n, n, a, lda, cwork, n )
      ! []            call stdlib_zlacpy( 'u', n, n, a, lda, cwork(n+1), n )
                    ! change: here index shifted by n to the left, cwork(1:n)
                    ! not needed for sigma only computation
                    do p = 1, n
                       temp1 = sva(iwork(p))
      ! []               call stdlib_zdscal( p, one/temp1, cwork(n+(p-1)*n+1), 1 )
                       call stdlib_zdscal( p, one/temp1, cwork((p-1)*n+1), 1_ilp )
                    end do
                 ! The Columns Of R Are Scaled To Have Unit Euclidean Lengths
      ! []               call stdlib_zpocon( 'u', n, cwork(n+1), n, one, temp1,
      ! []     $              cwork(n+n*n+1), rwork, ierr )
                    call stdlib_zpocon( 'U', n, cwork, n, one, temp1,cwork(n*n+1), rwork, ierr )
                              
                 end if
                 if ( temp1 /= zero ) then
                    sconda = one / sqrt(temp1)
                 else
                    sconda = - one
                 end if
                 ! sconda is an estimate of sqrt(||(r^* * r)^(-1)||_1).
                 ! n^(-1/4) * sconda <= ||r^(-1)||_2 <= n^(1/4) * sconda
              else
                 sconda = - one
              end if
           end if
           l2pert = l2pert .and. ( abs( a(1_ilp,1_ilp)/a(nr,nr) ) > sqrt(big1) )
           ! if there is no violent scaling, artificial perturbation is not needed.
           ! phase 3:
           if ( .not. ( rsvec .or. lsvec ) ) then
               ! singular values only
               ! .. transpose a(1:nr,1:n)
              do p = 1, min( n-1, nr )
                 call stdlib_zcopy( n-p, a(p,p+1), lda, a(p+1,p), 1_ilp )
                 call stdlib_zlacgv( n-p+1, a(p,p), 1_ilp )
              end do
              if ( nr == n ) a(n,n) = conjg(a(n,n))
              ! the following two do-loops introduce small relative perturbation
              ! into the strict upper triangle of the lower triangular matrix.
              ! small entries below the main diagonal are also changed.
              ! this modification is useful if the computing environment does not
              ! provide/allow flush to zero underflow, for it prevents many
              ! annoying denormalized numbers in case of strongly scaled matrices.
              ! the perturbation is structured so that it does not introduce any
              ! new perturbation of the singular values, and it does not destroy
              ! the job done by the preconditioner.
              ! the licence for this perturbation is in the variable l2pert, which
              ! should be .false. if flush to zero underflow is active.
              if ( .not. almort ) then
                 if ( l2pert ) then
                    ! xsc = sqrt(small)
                    xsc = epsln / real(n,KIND=dp)
                    do q = 1, nr
                       ctemp = cmplx(xsc*abs(a(q,q)),zero,KIND=dp)
                       do p = 1, n
                          if ( ( (p>q) .and. (abs(a(p,q))<=temp1) ).or. ( p < q ) )a(p,q) = &
                                    ctemp
           ! $                     a(p,q) = temp1 * ( a(p,q) / abs(a(p,q)) )
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1,nr-1, czero,czero, a(1_ilp,2_ilp),lda )
                 end if
                  ! Second Preconditioning Using The Qr Factorization
                 call stdlib_zgeqrf( n,nr, a,lda, cwork, cwork(n+1),lwork-n, ierr )
                 ! And Transpose Upper To Lower Triangular
                 do p = 1, nr - 1
                    call stdlib_zcopy( nr-p, a(p,p+1), lda, a(p+1,p), 1_ilp )
                    call stdlib_zlacgv( nr-p+1, a(p,p), 1_ilp )
                 end do
           end if
                 ! row-cyclic jacobi svd algorithm with column pivoting
                 ! .. again some perturbation (a "background noise") is added
                 ! to drown denormals
                 if ( l2pert ) then
                    ! xsc = sqrt(small)
                    xsc = epsln / real(n,KIND=dp)
                    do q = 1, nr
                       ctemp = cmplx(xsc*abs(a(q,q)),zero,KIND=dp)
                       do p = 1, nr
                          if ( ( (p>q) .and. (abs(a(p,q))<=temp1) ).or. ( p < q ) )a(p,q) = &
                                    ctemp
           ! $                   a(p,q) = temp1 * ( a(p,q) / abs(a(p,q)) )
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1, nr-1, czero, czero, a(1_ilp,2_ilp), lda )
                 end if
                 ! .. and one-sided jacobi rotations are started on a lower
                 ! triangular matrix (plus perturbation which is ignored in
                 ! the part which destroys triangular form (confusing?!))
                 call stdlib_zgesvj( 'L', 'N', 'N', nr, nr, a, lda, sva,n, v, ldv, cwork, lwork, &
                           rwork, lrwork, info )
                 scalem  = rwork(1_ilp)
                 numrank = nint(rwork(2_ilp),KIND=ilp)
           else if ( ( rsvec .and. ( .not. lsvec ) .and. ( .not. jracc ) ).or.( jracc .and. ( &
                     .not. lsvec ) .and. ( nr /= n ) ) ) then
              ! -> singular values and right singular vectors <-
              if ( almort ) then
                 ! In This Case Nr Equals N
                 do p = 1, nr
                    call stdlib_zcopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                    call stdlib_zlacgv( n-p+1, v(p,p), 1_ilp )
                 end do
                 if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1,nr-1, czero, czero, v(1_ilp,2_ilp), ldv )
                 call stdlib_zgesvj( 'L','U','N', n, nr, v, ldv, sva, nr, a, lda,cwork, lwork, &
                           rwork, lrwork, info )
                 scalem  = rwork(1_ilp)
                 numrank = nint(rwork(2_ilp),KIND=ilp)
              else
              ! .. two more qr factorizations ( one qrf is not enough, two require
              ! accumulated product of jacobi rotations, three are perfect )
                 if (nr>1_ilp) call stdlib_zlaset( 'L', nr-1,nr-1, czero, czero, a(2_ilp,1_ilp), lda )
                 call stdlib_zgelqf( nr,n, a, lda, cwork, cwork(n+1), lwork-n, ierr)
                 call stdlib_zlacpy( 'L', nr, nr, a, lda, v, ldv )
                 if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1,nr-1, czero, czero, v(1_ilp,2_ilp), ldv )
                 call stdlib_zgeqrf( nr, nr, v, ldv, cwork(n+1), cwork(2_ilp*n+1),lwork-2*n, ierr )
                           
                 do p = 1, nr
                    call stdlib_zcopy( nr-p+1, v(p,p), ldv, v(p,p), 1_ilp )
                    call stdlib_zlacgv( nr-p+1, v(p,p), 1_ilp )
                 end do
                 if (nr>1_ilp) call stdlib_zlaset('U', nr-1, nr-1, czero, czero, v(1_ilp,2_ilp), ldv)
                 call stdlib_zgesvj( 'L', 'U','N', nr, nr, v,ldv, sva, nr, u,ldu, cwork(n+1), &
                           lwork-n, rwork, lrwork, info )
                 scalem  = rwork(1_ilp)
                 numrank = nint(rwork(2_ilp),KIND=ilp)
                 if ( nr < n ) then
                    call stdlib_zlaset( 'A',n-nr, nr, czero,czero, v(nr+1,1_ilp),  ldv )
                    call stdlib_zlaset( 'A',nr, n-nr, czero,czero, v(1_ilp,nr+1),  ldv )
                    call stdlib_zlaset( 'A',n-nr,n-nr,czero,cone, v(nr+1,nr+1),ldv )
                 end if
              call stdlib_zunmlq( 'L', 'C', n, n, nr, a, lda, cwork,v, ldv, cwork(n+1), lwork-n, &
                        ierr )
              end if
               ! Permute The Rows Of V
               ! do 8991 p = 1, n
                  ! call stdlib_zcopy( n, v(p,1), ldv, a(iwork(p),1), lda )
                  8991 continue
               ! call stdlib_zlacpy( 'all', n, n, a, lda, v, ldv )
              call stdlib_zlapmr( .false., n, n, v, ldv, iwork )
               if ( transp ) then
                 call stdlib_zlacpy( 'A', n, n, v, ldv, u, ldu )
               end if
           else if ( jracc .and. (.not. lsvec) .and. ( nr== n ) ) then
              if (n>1_ilp) call stdlib_zlaset( 'L', n-1,n-1, czero, czero, a(2_ilp,1_ilp), lda )
              call stdlib_zgesvj( 'U','N','V', n, n, a, lda, sva, n, v, ldv,cwork, lwork, rwork, &
                        lrwork, info )
               scalem  = rwork(1_ilp)
               numrank = nint(rwork(2_ilp),KIND=ilp)
               call stdlib_zlapmr( .false., n, n, v, ldv, iwork )
           else if ( lsvec .and. ( .not. rsvec ) ) then
              ! Singular Values And Left Singular Vectors                 
              ! Second Preconditioning Step To Avoid Need To Accumulate
              ! jacobi rotations in the jacobi iterations.
              do p = 1, nr
                 call stdlib_zcopy( n-p+1, a(p,p), lda, u(p,p), 1_ilp )
                 call stdlib_zlacgv( n-p+1, u(p,p), 1_ilp )
              end do
              if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1, nr-1, czero, czero, u(1_ilp,2_ilp), ldu )
              call stdlib_zgeqrf( n, nr, u, ldu, cwork(n+1), cwork(2_ilp*n+1),lwork-2*n, ierr )
                        
              do p = 1, nr - 1
                 call stdlib_zcopy( nr-p, u(p,p+1), ldu, u(p+1,p), 1_ilp )
                 call stdlib_zlacgv( n-p+1, u(p,p), 1_ilp )
              end do
              if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1, nr-1, czero, czero, u(1_ilp,2_ilp), ldu )
              call stdlib_zgesvj( 'L', 'U', 'N', nr,nr, u, ldu, sva, nr, a,lda, cwork(n+1), lwork-&
                        n, rwork, lrwork, info )
              scalem  = rwork(1_ilp)
              numrank = nint(rwork(2_ilp),KIND=ilp)
              if ( nr < m ) then
                 call stdlib_zlaset( 'A',  m-nr, nr,czero, czero, u(nr+1,1_ilp), ldu )
                 if ( nr < n1 ) then
                    call stdlib_zlaset( 'A',nr, n1-nr, czero, czero, u(1_ilp,nr+1),ldu )
                    call stdlib_zlaset( 'A',m-nr,n1-nr,czero,cone,u(nr+1,nr+1),ldu )
                 end if
              end if
              call stdlib_zunmqr( 'L', 'N', m, n1, n, a, lda, cwork, u,ldu, cwork(n+1), lwork-n, &
                        ierr )
              if ( rowpiv )call stdlib_zlaswp( n1, u, ldu, 1_ilp, m-1, iwork(iwoff+1), -1_ilp )
              do p = 1, n1
                 xsc = one / stdlib_dznrm2( m, u(1_ilp,p), 1_ilp )
                 call stdlib_zdscal( m, xsc, u(1_ilp,p), 1_ilp )
              end do
              if ( transp ) then
                 call stdlib_zlacpy( 'A', n, n, u, ldu, v, ldv )
              end if
           else
              ! Full Svd 
              if ( .not. jracc ) then
              if ( .not. almort ) then
                 ! second preconditioning step (qrf [with pivoting])
                 ! note that the composition of transpose, qrf and transpose is
                 ! equivalent to an lqf call. since in many libraries the qrf
                 ! seems to be better optimized than the lqf, we do explicit
                 ! transpose and use the qrf. this is subject to changes in an
                 ! optimized implementation of stdlib_zgejsv.
                 do p = 1, nr
                    call stdlib_zcopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                    call stdlib_zlacgv( n-p+1, v(p,p), 1_ilp )
                 end do
                 ! The Following Two Loops Perturb Small Entries To Avoid
                 ! denormals in the second qr factorization, where they are
                 ! as good as zeros. this is done to avoid painfully slow
                 ! computation with denormals. the relative size of the perturbation
                 ! is a parameter that can be changed by the implementer.
                 ! this perturbation device will be obsolete on machines with
                 ! properly implemented arithmetic.
                 ! to switch it off, set l2pert=.false. to remove it from  the
                 ! code, remove the action under l2pert=.true., leave the else part.
                 ! the following two loops should be blocked and fused with the
                 ! transposed copy above.
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do q = 1, nr
                       ctemp = cmplx(xsc*abs( v(q,q) ),zero,KIND=dp)
                       do p = 1, n
                          if ( ( p > q ) .and. ( abs(v(p,q)) <= temp1 ).or. ( p < q ) )v(p,q) = &
                                    ctemp
           ! $                   v(p,q) = temp1 * ( v(p,q) / abs(v(p,q)) )
                          if ( p < q ) v(p,q) = - v(p,q)
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1, nr-1, czero, czero, v(1_ilp,2_ilp), ldv )
                 end if
                 ! estimate the row scaled condition number of r1
                 ! (if r1 is rectangular, n > nr, then the condition number
                 ! of the leading nr x nr submatrix is estimated.)
                 call stdlib_zlacpy( 'L', nr, nr, v, ldv, cwork(2_ilp*n+1), nr )
                 do p = 1, nr
                    temp1 = stdlib_dznrm2(nr-p+1,cwork(2_ilp*n+(p-1)*nr+p),1_ilp)
                    call stdlib_zdscal(nr-p+1,one/temp1,cwork(2_ilp*n+(p-1)*nr+p),1_ilp)
                 end do
                 call stdlib_zpocon('L',nr,cwork(2_ilp*n+1),nr,one,temp1,cwork(2_ilp*n+nr*nr+1),rwork,&
                           ierr)
                 condr1 = one / sqrt(temp1)
                 ! Here Need A Second Opinion On The Condition Number
                 ! Then Assume Worst Case Scenario
                 ! r1 is ok for inverse <=> condr1 < real(n,KIND=dp)
                 ! more conservative    <=> condr1 < sqrt(real(n,KIND=dp))
                 cond_ok = sqrt(sqrt(real(nr,KIND=dp)))
      ! [tp]       cond_ok is a tuning parameter.
                 if ( condr1 < cond_ok ) then
                    ! .. the second qrf without pivoting. note: in an optimized
                    ! implementation, this qrf should be implemented as the qrf
                    ! of a lower triangular matrix.
                    ! r1^* = q2 * r2
                    call stdlib_zgeqrf( n, nr, v, ldv, cwork(n+1), cwork(2_ilp*n+1),lwork-2*n, ierr )
                              
                    if ( l2pert ) then
                       xsc = sqrt(small)/epsln
                       do p = 2, nr
                          do q = 1, p - 1
                             ctemp=cmplx(xsc*min(abs(v(p,p)),abs(v(q,q))),zero,KIND=dp)
                             if ( abs(v(q,p)) <= temp1 )v(q,p) = ctemp
           ! $                     v(q,p) = temp1 * ( v(q,p) / abs(v(q,p)) )
                          end do
                       end do
                    end if
                    if ( nr /= n )call stdlib_zlacpy( 'A', n, nr, v, ldv, cwork(2_ilp*n+1), n )
                              
                    ! .. save ...
                 ! This Transposed Copy Should Be Better Than Naive
                    do p = 1, nr - 1
                       call stdlib_zcopy( nr-p, v(p,p+1), ldv, v(p+1,p), 1_ilp )
                       call stdlib_zlacgv(nr-p+1, v(p,p), 1_ilp )
                    end do
                    v(nr,nr)=conjg(v(nr,nr))
                    condr2 = condr1
                 else
                    ! .. ill-conditioned case: second qrf with pivoting
                    ! note that windowed pivoting would be equally good
                    ! numerically, and more run-time efficient. so, in
                    ! an optimal implementation, the next call to stdlib_zgeqp3
                    ! should be replaced with eg. call zgeqpx (acm toms #782)
                    ! with properly (carefully) chosen parameters.
                    ! r1^* * p2 = q2 * r2
                    do p = 1, nr
                       iwork(n+p) = 0_ilp
                    end do
                    call stdlib_zgeqp3( n, nr, v, ldv, iwork(n+1), cwork(n+1),cwork(2_ilp*n+1), lwork-&
                              2_ilp*n, rwork, ierr )
      ! *               call stdlib_zgeqrf( n, nr, v, ldv, cwork(n+1), cwork(2*n+1),
      ! *     $              lwork-2*n, ierr )
                    if ( l2pert ) then
                       xsc = sqrt(small)
                       do p = 2, nr
                          do q = 1, p - 1
                             ctemp=cmplx(xsc*min(abs(v(p,p)),abs(v(q,q))),zero,KIND=dp)
                             if ( abs(v(q,p)) <= temp1 )v(q,p) = ctemp
           ! $                     v(q,p) = temp1 * ( v(q,p) / abs(v(q,p)) )
                          end do
                       end do
                    end if
                    call stdlib_zlacpy( 'A', n, nr, v, ldv, cwork(2_ilp*n+1), n )
                    if ( l2pert ) then
                       xsc = sqrt(small)
                       do p = 2, nr
                          do q = 1, p - 1
                             ctemp=cmplx(xsc*min(abs(v(p,p)),abs(v(q,q))),zero,KIND=dp)
                              ! v(p,q) = - temp1*( v(q,p) / abs(v(q,p)) )
                             v(p,q) = - ctemp
                          end do
                       end do
                    else
                       if (nr>1_ilp) call stdlib_zlaset( 'L',nr-1,nr-1,czero,czero,v(2_ilp,1_ilp),ldv )
                    end if
                    ! now, compute r2 = l3 * q3, the lq factorization.
                    call stdlib_zgelqf( nr, nr, v, ldv, cwork(2_ilp*n+n*nr+1),cwork(2_ilp*n+n*nr+nr+1), &
                              lwork-2*n-n*nr-nr, ierr )
                    ! And Estimate The Condition Number
                    call stdlib_zlacpy( 'L',nr,nr,v,ldv,cwork(2_ilp*n+n*nr+nr+1),nr )
                    do p = 1, nr
                       temp1 = stdlib_dznrm2( p, cwork(2_ilp*n+n*nr+nr+p), nr )
                       call stdlib_zdscal( p, one/temp1, cwork(2_ilp*n+n*nr+nr+p), nr )
                    end do
                    call stdlib_zpocon( 'L',nr,cwork(2_ilp*n+n*nr+nr+1),nr,one,temp1,cwork(2_ilp*n+n*nr+&
                              nr+nr*nr+1),rwork,ierr )
                    condr2 = one / sqrt(temp1)
                    if ( condr2 >= cond_ok ) then
                       ! Save The Householder Vectors Used For Q3
                       ! (this overwrites the copy of r2, as it will not be
                       ! needed in this branch, but it does not overwritte the
                       ! huseholder vectors of q2.).
                       call stdlib_zlacpy( 'U', nr, nr, v, ldv, cwork(2_ilp*n+1), n )
                       ! And The Rest Of The Information On Q3 Is In
                       ! work(2*n+n*nr+1:2*n+n*nr+n)
                    end if
                 end if
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do q = 2, nr
                       ctemp = xsc * v(q,q)
                       do p = 1, q - 1
                           ! v(p,q) = - temp1*( v(p,q) / abs(v(p,q)) )
                          v(p,q) = - ctemp
                       end do
                    end do
                 else
                    if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1,nr-1, czero,czero, v(1_ilp,2_ilp), ldv )
                 end if
              ! second preconditioning finished; continue with jacobi svd
              ! the input matrix is lower trinagular.
              ! recover the right singular vectors as solution of a well
              ! conditioned triangular matrix equation.
                 if ( condr1 < cond_ok ) then
                    call stdlib_zgesvj( 'L','U','N',nr,nr,v,ldv,sva,nr,u, ldu,cwork(2_ilp*n+n*nr+nr+1)&
                              ,lwork-2*n-n*nr-nr,rwork,lrwork, info )
                    scalem  = rwork(1_ilp)
                    numrank = nint(rwork(2_ilp),KIND=ilp)
                    do p = 1, nr
                       call stdlib_zcopy(  nr, v(1_ilp,p), 1_ilp, u(1_ilp,p), 1_ilp )
                       call stdlib_zdscal( nr, sva(p),    v(1_ilp,p), 1_ilp )
                    end do
              ! Pick The Right Matrix Equation And Solve It
                    if ( nr == n ) then
       ! :))             .. best case, r1 is inverted. the solution of this matrix
                       ! equation is q2*v2 = the product of the jacobi rotations
                       ! used in stdlib_zgesvj, premultiplied with the orthogonal matrix
                       ! from the second qr factorization.
                       call stdlib_ztrsm('L','U','N','N', nr,nr,cone, a,lda, v,ldv)
                    else
                       ! .. r1 is well conditioned, but non-square. adjoint of r2
                       ! is inverted to get the product of the jacobi rotations
                       ! used in stdlib_zgesvj. the q-factor from the second qr
                       ! factorization is then built in explicitly.
                       call stdlib_ztrsm('L','U','C','N',nr,nr,cone,cwork(2_ilp*n+1),n,v,ldv)
                       if ( nr < n ) then
                       call stdlib_zlaset('A',n-nr,nr,czero,czero,v(nr+1,1_ilp),ldv)
                       call stdlib_zlaset('A',nr,n-nr,czero,czero,v(1_ilp,nr+1),ldv)
                       call stdlib_zlaset('A',n-nr,n-nr,czero,cone,v(nr+1,nr+1),ldv)
                       end if
                       call stdlib_zunmqr('L','N',n,n,nr,cwork(2_ilp*n+1),n,cwork(n+1),v,ldv,cwork(&
                                 2_ilp*n+n*nr+nr+1),lwork-2*n-n*nr-nr,ierr)
                    end if
                 else if ( condr2 < cond_ok ) then
                    ! the matrix r2 is inverted. the solution of the matrix equation
                    ! is q3^* * v3 = the product of the jacobi rotations (appplied to
                    ! the lower triangular l3 from the lq factorization of
                    ! r2=l3*q3), pre-multiplied with the transposed q3.
                    call stdlib_zgesvj( 'L', 'U', 'N', nr, nr, v, ldv, sva, nr, u,ldu, cwork(2_ilp*n+&
                              n*nr+nr+1), lwork-2*n-n*nr-nr,rwork, lrwork, info )
                    scalem  = rwork(1_ilp)
                    numrank = nint(rwork(2_ilp),KIND=ilp)
                    do p = 1, nr
                       call stdlib_zcopy( nr, v(1_ilp,p), 1_ilp, u(1_ilp,p), 1_ilp )
                       call stdlib_zdscal( nr, sva(p),    u(1_ilp,p), 1_ilp )
                    end do
                    call stdlib_ztrsm('L','U','N','N',nr,nr,cone,cwork(2_ilp*n+1),n,u,ldu)
                    ! Apply The Permutation From The Second Qr Factorization
                    do q = 1, nr
                       do p = 1, nr
                          cwork(2_ilp*n+n*nr+nr+iwork(n+p)) = u(p,q)
                       end do
                       do p = 1, nr
                          u(p,q) = cwork(2_ilp*n+n*nr+nr+p)
                       end do
                    end do
                    if ( nr < n ) then
                       call stdlib_zlaset( 'A',n-nr,nr,czero,czero,v(nr+1,1_ilp),ldv )
                       call stdlib_zlaset( 'A',nr,n-nr,czero,czero,v(1_ilp,nr+1),ldv )
                       call stdlib_zlaset('A',n-nr,n-nr,czero,cone,v(nr+1,nr+1),ldv)
                    end if
                    call stdlib_zunmqr( 'L','N',n,n,nr,cwork(2_ilp*n+1),n,cwork(n+1),v,ldv,cwork(2_ilp*n+&
                              n*nr+nr+1),lwork-2*n-n*nr-nr,ierr )
                 else
                    ! last line of defense.
       ! #:(          this is a rather pathological case: no scaled condition
                    ! improvement after two pivoted qr factorizations. other
                    ! possibility is that the rank revealing qr factorization
                    ! or the condition estimator has failed, or the cond_ok
                    ! is set very close to one (which is unnecessary). normally,
                    ! this branch should never be executed, but in rare cases of
                    ! failure of the rrqr or condition estimator, the last line of
                    ! defense ensures that stdlib_zgejsv completes the task.
                    ! compute the full svd of l3 using stdlib_zgesvj with explicit
                    ! accumulation of jacobi rotations.
                    call stdlib_zgesvj( 'L', 'U', 'V', nr, nr, v, ldv, sva, nr, u,ldu, cwork(2_ilp*n+&
                              n*nr+nr+1), lwork-2*n-n*nr-nr,rwork, lrwork, info )
                    scalem  = rwork(1_ilp)
                    numrank = nint(rwork(2_ilp),KIND=ilp)
                    if ( nr < n ) then
                       call stdlib_zlaset( 'A',n-nr,nr,czero,czero,v(nr+1,1_ilp),ldv )
                       call stdlib_zlaset( 'A',nr,n-nr,czero,czero,v(1_ilp,nr+1),ldv )
                       call stdlib_zlaset('A',n-nr,n-nr,czero,cone,v(nr+1,nr+1),ldv)
                    end if
                    call stdlib_zunmqr( 'L','N',n,n,nr,cwork(2_ilp*n+1),n,cwork(n+1),v,ldv,cwork(2_ilp*n+&
                              n*nr+nr+1),lwork-2*n-n*nr-nr,ierr )
                    call stdlib_zunmlq( 'L', 'C', nr, nr, nr, cwork(2_ilp*n+1), n,cwork(2_ilp*n+n*nr+1), &
                              u, ldu, cwork(2_ilp*n+n*nr+nr+1),lwork-2*n-n*nr-nr, ierr )
                    do q = 1, nr
                       do p = 1, nr
                          cwork(2_ilp*n+n*nr+nr+iwork(n+p)) = u(p,q)
                       end do
                       do p = 1, nr
                          u(p,q) = cwork(2_ilp*n+n*nr+nr+p)
                       end do
                    end do
                 end if
                 ! permute the rows of v using the (column) permutation from the
                 ! first qrf. also, scale the columns to make them unit in
                 ! euclidean norm. this applies to all cases.
                 temp1 = sqrt(real(n,KIND=dp)) * epsln
                 do q = 1, n
                    do p = 1, n
                       cwork(2_ilp*n+n*nr+nr+iwork(p)) = v(p,q)
                    end do
                    do p = 1, n
                       v(p,q) = cwork(2_ilp*n+n*nr+nr+p)
                    end do
                    xsc = one / stdlib_dznrm2( n, v(1_ilp,q), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_zdscal( n, xsc,&
                               v(1_ilp,q), 1_ilp )
                 end do
                 ! at this moment, v contains the right singular vectors of a.
                 ! next, assemble the left singular vector matrix u (m x n).
                 if ( nr < m ) then
                    call stdlib_zlaset('A', m-nr, nr, czero, czero, u(nr+1,1_ilp), ldu)
                    if ( nr < n1 ) then
                       call stdlib_zlaset('A',nr,n1-nr,czero,czero,u(1_ilp,nr+1),ldu)
                       call stdlib_zlaset('A',m-nr,n1-nr,czero,cone,u(nr+1,nr+1),ldu)
                    end if
                 end if
                 ! the q matrix from the first qrf is built into the left singular
                 ! matrix u. this applies to all cases.
                 call stdlib_zunmqr( 'L', 'N', m, n1, n, a, lda, cwork, u,ldu, cwork(n+1), lwork-&
                           n, ierr )
                 ! the columns of u are normalized. the cost is o(m*n) flops.
                 temp1 = sqrt(real(m,KIND=dp)) * epsln
                 do p = 1, nr
                    xsc = one / stdlib_dznrm2( m, u(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_zdscal( m, xsc,&
                               u(1_ilp,p), 1_ilp )
                 end do
                 ! if the initial qrf is computed with row pivoting, the left
                 ! singular vectors must be adjusted.
                 if ( rowpiv )call stdlib_zlaswp( n1, u, ldu, 1_ilp, m-1, iwork(iwoff+1), -1_ilp )
              else
              ! The Initial Matrix A Has Almost Orthogonal Columns And
              ! the second qrf is not needed
                 call stdlib_zlacpy( 'U', n, n, a, lda, cwork(n+1), n )
                 if ( l2pert ) then
                    xsc = sqrt(small)
                    do p = 2, n
                       ctemp = xsc * cwork( n + (p-1)*n + p )
                       do q = 1, p - 1
                           ! cwork(n+(q-1)*n+p)=-temp1 * ( cwork(n+(p-1)*n+q) /
           ! $                                        abs(cwork(n+(p-1)*n+q)) )
                          cwork(n+(q-1)*n+p)=-ctemp
                       end do
                    end do
                 else
                    call stdlib_zlaset( 'L',n-1,n-1,czero,czero,cwork(n+2),n )
                 end if
                 call stdlib_zgesvj( 'U', 'U', 'N', n, n, cwork(n+1), n, sva,n, u, ldu, cwork(n+&
                           n*n+1), lwork-n-n*n, rwork, lrwork,info )
                 scalem  = rwork(1_ilp)
                 numrank = nint(rwork(2_ilp),KIND=ilp)
                 do p = 1, n
                    call stdlib_zcopy( n, cwork(n+(p-1)*n+1), 1_ilp, u(1_ilp,p), 1_ilp )
                    call stdlib_zdscal( n, sva(p), cwork(n+(p-1)*n+1), 1_ilp )
                 end do
                 call stdlib_ztrsm( 'L', 'U', 'N', 'N', n, n,cone, a, lda, cwork(n+1), n )
                 do p = 1, n
                    call stdlib_zcopy( n, cwork(n+p), n, v(iwork(p),1_ilp), ldv )
                 end do
                 temp1 = sqrt(real(n,KIND=dp))*epsln
                 do p = 1, n
                    xsc = one / stdlib_dznrm2( n, v(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_zdscal( n, xsc,&
                               v(1_ilp,p), 1_ilp )
                 end do
                 ! assemble the left singular vector matrix u (m x n).
                 if ( n < m ) then
                    call stdlib_zlaset( 'A',  m-n, n, czero, czero, u(n+1,1_ilp), ldu )
                    if ( n < n1 ) then
                       call stdlib_zlaset('A',n,  n1-n, czero, czero,  u(1_ilp,n+1),ldu)
                       call stdlib_zlaset( 'A',m-n,n1-n, czero, cone,u(n+1,n+1),ldu)
                    end if
                 end if
                 call stdlib_zunmqr( 'L', 'N', m, n1, n, a, lda, cwork, u,ldu, cwork(n+1), lwork-&
                           n, ierr )
                 temp1 = sqrt(real(m,KIND=dp))*epsln
                 do p = 1, n1
                    xsc = one / stdlib_dznrm2( m, u(1_ilp,p), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_zdscal( m, xsc,&
                               u(1_ilp,p), 1_ilp )
                 end do
                 if ( rowpiv )call stdlib_zlaswp( n1, u, ldu, 1_ilp, m-1, iwork(iwoff+1), -1_ilp )
              end if
              ! end of the  >> almost orthogonal case <<  in the full svd
              else
              ! this branch deploys a preconditioned jacobi svd with explicitly
              ! accumulated rotations. it is included as optional, mainly for
              ! experimental purposes. it does perform well, and can also be used.
              ! in this implementation, this branch will be automatically activated
              ! if the  condition number sigma_max(a) / sigma_min(a) is predicted
              ! to be greater than the overflow threshold. this is because the
              ! a posteriori computation of the singular vectors assumes robust
              ! implementation of blas and some lapack procedures, capable of working
              ! in presence of extreme values, e.g. when the singular values spread from
              ! the underflow to the overflow threshold.
              do p = 1, nr
                 call stdlib_zcopy( n-p+1, a(p,p), lda, v(p,p), 1_ilp )
                 call stdlib_zlacgv( n-p+1, v(p,p), 1_ilp )
              end do
              if ( l2pert ) then
                 xsc = sqrt(small/epsln)
                 do q = 1, nr
                    ctemp = cmplx(xsc*abs( v(q,q) ),zero,KIND=dp)
                    do p = 1, n
                       if ( ( p > q ) .and. ( abs(v(p,q)) <= temp1 ).or. ( p < q ) )v(p,q) = &
                                 ctemp
           ! $                v(p,q) = temp1 * ( v(p,q) / abs(v(p,q)) )
                       if ( p < q ) v(p,q) = - v(p,q)
                    end do
                 end do
              else
                 if (nr>1_ilp) call stdlib_zlaset( 'U', nr-1, nr-1, czero, czero, v(1_ilp,2_ilp), ldv )
              end if
              call stdlib_zgeqrf( n, nr, v, ldv, cwork(n+1), cwork(2_ilp*n+1),lwork-2*n, ierr )
                        
              call stdlib_zlacpy( 'L', n, nr, v, ldv, cwork(2_ilp*n+1), n )
              do p = 1, nr
                 call stdlib_zcopy( nr-p+1, v(p,p), ldv, u(p,p), 1_ilp )
                 call stdlib_zlacgv( nr-p+1, u(p,p), 1_ilp )
              end do
              if ( l2pert ) then
                 xsc = sqrt(small/epsln)
                 do q = 2, nr
                    do p = 1, q - 1
                       ctemp = cmplx(xsc * min(abs(u(p,p)),abs(u(q,q))),zero,KIND=dp)
                        ! u(p,q) = - temp1 * ( u(q,p) / abs(u(q,p)) )
                       u(p,q) = - ctemp
                    end do
                 end do
              else
                 if (nr>1_ilp) call stdlib_zlaset('U', nr-1, nr-1, czero, czero, u(1_ilp,2_ilp), ldu )
              end if
              call stdlib_zgesvj( 'L', 'U', 'V', nr, nr, u, ldu, sva,n, v, ldv, cwork(2_ilp*n+n*nr+1),&
                         lwork-2*n-n*nr,rwork, lrwork, info )
              scalem  = rwork(1_ilp)
              numrank = nint(rwork(2_ilp),KIND=ilp)
              if ( nr < n ) then
                 call stdlib_zlaset( 'A',n-nr,nr,czero,czero,v(nr+1,1_ilp),ldv )
                 call stdlib_zlaset( 'A',nr,n-nr,czero,czero,v(1_ilp,nr+1),ldv )
                 call stdlib_zlaset( 'A',n-nr,n-nr,czero,cone,v(nr+1,nr+1),ldv )
              end if
              call stdlib_zunmqr( 'L','N',n,n,nr,cwork(2_ilp*n+1),n,cwork(n+1),v,ldv,cwork(2_ilp*n+n*nr+&
                        nr+1),lwork-2*n-n*nr-nr,ierr )
                 ! permute the rows of v using the (column) permutation from the
                 ! first qrf. also, scale the columns to make them unit in
                 ! euclidean norm. this applies to all cases.
                 temp1 = sqrt(real(n,KIND=dp)) * epsln
                 do q = 1, n
                    do p = 1, n
                       cwork(2_ilp*n+n*nr+nr+iwork(p)) = v(p,q)
                    end do
                    do p = 1, n
                       v(p,q) = cwork(2_ilp*n+n*nr+nr+p)
                    end do
                    xsc = one / stdlib_dznrm2( n, v(1_ilp,q), 1_ilp )
                    if ( (xsc < (one-temp1)) .or. (xsc > (one+temp1)) )call stdlib_zdscal( n, xsc,&
                               v(1_ilp,q), 1_ilp )
                 end do
                 ! at this moment, v contains the right singular vectors of a.
                 ! next, assemble the left singular vector matrix u (m x n).
              if ( nr < m ) then
                 call stdlib_zlaset( 'A',  m-nr, nr, czero, czero, u(nr+1,1_ilp), ldu )
                 if ( nr < n1 ) then
                    call stdlib_zlaset('A',nr,  n1-nr, czero, czero,  u(1_ilp,nr+1),ldu)
                    call stdlib_zlaset('A',m-nr,n1-nr, czero, cone,u(nr+1,nr+1),ldu)
                 end if
              end if
              call stdlib_zunmqr( 'L', 'N', m, n1, n, a, lda, cwork, u,ldu, cwork(n+1), lwork-n, &
                        ierr )
                 if ( rowpiv )call stdlib_zlaswp( n1, u, ldu, 1_ilp, m-1, iwork(iwoff+1), -1_ilp )
              end if
              if ( transp ) then
                 ! .. swap u and v because the procedure worked on a^*
                 do p = 1, n
                    call stdlib_zswap( n, u(1_ilp,p), 1_ilp, v(1_ilp,p), 1_ilp )
                 end do
              end if
           end if
           ! end of the full svd
           ! undo scaling, if necessary (and possible)
           if ( uscal2 <= (big/sva(1_ilp))*uscal1 ) then
              call stdlib_dlascl( 'G', 0_ilp, 0_ilp, uscal1, uscal2, nr, 1_ilp, sva, n, ierr )
              uscal1 = one
              uscal2 = one
           end if
           if ( nr < n ) then
              do p = nr+1, n
                 sva(p) = zero
              end do
           end if
           rwork(1_ilp) = uscal2 * scalem
           rwork(2_ilp) = uscal1
           if ( errest ) rwork(3_ilp) = sconda
           if ( lsvec .and. rsvec ) then
              rwork(4_ilp) = condr1
              rwork(5_ilp) = condr2
           end if
           if ( l2tran ) then
              rwork(6_ilp) = entra
              rwork(7_ilp) = entrat
           end if
           iwork(1_ilp) = nr
           iwork(2_ilp) = numrank
           iwork(3_ilp) = warning
           if ( transp ) then
               iwork(4_ilp) =  1_ilp
           else
               iwork(4_ilp) = -1_ilp
           end if
           return
     end subroutine stdlib_zgejsv




     pure module subroutine stdlib_sgesvj( joba, jobu, jobv, m, n, a, lda, sva, mv, v,ldv, work, lwork, &
     !! SGESVJ computes the singular value decomposition (SVD) of a real
     !! M-by-N matrix A, where M >= N. The SVD of A is written as
     !! [++]   [xx]   [x0]   [xx]
     !! A = U * SIGMA * V^t,  [++] = [xx] * [ox] * [xx]
     !! [++]   [xx]
     !! where SIGMA is an N-by-N diagonal matrix, U is an M-by-N orthonormal
     !! matrix, and V is an N-by-N orthogonal matrix. The diagonal elements
     !! of SIGMA are the singular values of A. The columns of U and V are the
     !! left and the right singular vectors of A, respectively.
     !! SGESVJ can sometimes compute tiny singular values and their singular vectors much
     !! more accurately than other SVD routines, see below under Further Details.
               info )
        ! -- lapack computational routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_sp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldv, lwork, m, mv, n
           character, intent(in) :: joba, jobu, jobv
           ! Array Arguments 
           real(sp), intent(inout) :: a(lda,*), v(ldv,*), work(lwork)
           real(sp), intent(out) :: sva(n)
        ! =====================================================================
           ! Local Parameters 
           integer(ilp), parameter :: nsweep = 30_ilp
           
           
           ! Local Scalars 
           real(sp) :: aapp, aapp0, aapq, aaqq, apoaq, aqoap, big, bigtheta, cs, ctol, epsln, &
           large, mxaapq, mxsinj, rootbig, rooteps, rootsfmin, roottol, skl, sfmin, small, sn, t, &
                     temp1, theta, thsign, tol
           integer(ilp) :: blskip, emptsw, i, ibr, ierr, igl, ijblsk, ir1, iswrot, jbc, jgl, kbl, &
                     lkahead, mvl, n2, n34, n4, nbl, notrot, p, pskipped, q, rowskip, swband
           logical(lk) :: applv, goscale, lower, lsvec, noscale, rotok, rsvec, uctol, &
                     upper
           ! Local Arrays 
           real(sp) :: fastr(5_ilp)
           ! Intrinsic Functions 
           ! from lapack
           ! from lapack
           ! Executable Statements 
           ! test the input arguments
           lsvec = stdlib_lsame( jobu, 'U' )
           uctol = stdlib_lsame( jobu, 'C' )
           rsvec = stdlib_lsame( jobv, 'V' )
           applv = stdlib_lsame( jobv, 'A' )
           upper = stdlib_lsame( joba, 'U' )
           lower = stdlib_lsame( joba, 'L' )
           if( .not.( upper .or. lower .or. stdlib_lsame( joba, 'G' ) ) ) then
              info = -1_ilp
           else if( .not.( lsvec .or. uctol .or. stdlib_lsame( jobu, 'N' ) ) ) then
              info = -2_ilp
           else if( .not.( rsvec .or. applv .or. stdlib_lsame( jobv, 'N' ) ) ) then
              info = -3_ilp
           else if( m<0_ilp ) then
              info = -4_ilp
           else if( ( n<0_ilp ) .or. ( n>m ) ) then
              info = -5_ilp
           else if( lda<m ) then
              info = -7_ilp
           else if( mv<0_ilp ) then
              info = -9_ilp
           else if( ( rsvec .and. ( ldv<n ) ) .or.( applv .and. ( ldv<mv ) ) ) then
              info = -11_ilp
           else if( uctol .and. ( work( 1_ilp )<=one ) ) then
              info = -12_ilp
           else if( lwork<max( m+n, 6_ilp ) ) then
              info = -13_ilp
           else
              info = 0_ilp
           end if
           ! #:(
           if( info/=0_ilp ) then
              call stdlib_xerbla( 'SGESVJ', -info )
              return
           end if
       ! #:) quick return for void matrix
           if( ( m==0 ) .or. ( n==0 ) )return
           ! set numerical parameters
           ! the stopping criterion for jacobi rotations is
           ! max_{i<>j}|a(:,i)^t * a(:,j)|/(||a(:,i)||*||a(:,j)||) < ctol*eps
           ! where eps is the round-off and ctol is defined as follows:
           if( uctol ) then
              ! ... user controlled
              ctol = work( 1_ilp )
           else
              ! ... default
              if( lsvec .or. rsvec .or. applv ) then
                 ctol = sqrt( real( m,KIND=sp) )
              else
                 ctol = real( m,KIND=sp)
              end if
           end if
           ! ... and the machine dependent parameters are
      ! [!]  (make sure that stdlib_slamch() works properly on the target machine.)
           epsln = stdlib_slamch( 'EPSILON' )
           rooteps = sqrt( epsln )
           sfmin = stdlib_slamch( 'SAFEMINIMUM' )
           rootsfmin = sqrt( sfmin )
           small = sfmin / epsln
           big = stdlib_slamch( 'OVERFLOW' )
           ! big         = one    / sfmin
           rootbig = one / rootsfmin
           large = big / sqrt( real( m*n,KIND=sp) )
           bigtheta = one / rooteps
           tol = ctol*epsln
           roottol = sqrt( tol )
           if( real( m,KIND=sp)*epsln>=one ) then
              info = -4_ilp
              call stdlib_xerbla( 'SGESVJ', -info )
              return
           end if
           ! initialize the right singular vector matrix.
           if( rsvec ) then
              mvl = n
              call stdlib_slaset( 'A', mvl, n, zero, one, v, ldv )
           else if( applv ) then
              mvl = mv
           end if
           rsvec = rsvec .or. applv
           ! initialize sva( 1:n ) = ( ||a e_i||_2, i = 1:n )
      ! (!)  if necessary, scale a to protect the largest singular value
           ! from overflow. it is possible that saving the largest singular
           ! value destroys the information about the small ones.
           ! this initial scaling is almost minimal in the sense that the
           ! goal is to make sure that no column norm overflows, and that
           ! sqrt(n)*max_i sva(i) does not overflow. if infinite entries
           ! in a are detected, the procedure returns with info=-6.
           skl = one / sqrt( real( m,KIND=sp)*real( n,KIND=sp) )
           noscale = .true.
           goscale = .true.
           if( lower ) then
              ! the input matrix is m-by-n lower triangular (trapezoidal)
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_slassq( m-p+1, a( p, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'SGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           else if( upper ) then
              ! the input matrix is m-by-n upper triangular (trapezoidal)
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_slassq( p, a( 1_ilp, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'SGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           else
              ! the input matrix is m-by-n general dense
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_slassq( m, a( 1_ilp, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'SGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           end if
           if( noscale )skl = one
           ! move the smaller part of the spectrum from the underflow threshold
      ! (!)  start by determining the position of the nonzero entries of the
           ! array sva() relative to ( sfmin, big ).
           aapp = zero
           aaqq = big
           do p = 1, n
              if( sva( p )/=zero )aaqq = min( aaqq, sva( p ) )
              aapp = max( aapp, sva( p ) )
           end do
       ! #:) quick return for zero matrix
           if( aapp==zero ) then
              if( lsvec )call stdlib_slaset( 'G', m, n, zero, one, a, lda )
              work( 1_ilp ) = one
              work( 2_ilp ) = zero
              work( 3_ilp ) = zero
              work( 4_ilp ) = zero
              work( 5_ilp ) = zero
              work( 6_ilp ) = zero
              return
           end if
       ! #:) quick return for one-column matrix
           if( n==1_ilp ) then
              if( lsvec )call stdlib_slascl( 'G', 0_ilp, 0_ilp, sva( 1_ilp ), skl, m, 1_ilp,a( 1_ilp, 1_ilp ), lda, ierr )
                        
              work( 1_ilp ) = one / skl
              if( sva( 1_ilp )>=sfmin ) then
                 work( 2_ilp ) = one
              else
                 work( 2_ilp ) = zero
              end if
              work( 3_ilp ) = zero
              work( 4_ilp ) = zero
              work( 5_ilp ) = zero
              work( 6_ilp ) = zero
              return
           end if
           ! protect small singular values from underflow, and try to
           ! avoid underflows/overflows in computing jacobi rotations.
           sn = sqrt( sfmin / epsln )
           temp1 = sqrt( big / real( n,KIND=sp) )
           if( ( aapp<=sn ) .or. ( aaqq>=temp1 ) .or.( ( sn<=aaqq ) .and. ( aapp<=temp1 ) ) ) &
                     then
              temp1 = min( big, temp1 / aapp )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq<=sn ) .and. ( aapp<=temp1 ) ) then
              temp1 = min( sn / aaqq, big / ( aapp*sqrt( real( n,KIND=sp) ) ) )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq>=sn ) .and. ( aapp>=temp1 ) ) then
              temp1 = max( sn / aaqq, temp1 / aapp )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq<=sn ) .and. ( aapp>=temp1 ) ) then
              temp1 = min( sn / aaqq, big / ( sqrt( real( n,KIND=sp) )*aapp ) )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else
              temp1 = one
           end if
           ! scale, if necessary
           if( temp1/=one ) then
              call stdlib_slascl( 'G', 0_ilp, 0_ilp, one, temp1, n, 1_ilp, sva, n, ierr )
           end if
           skl = temp1*skl
           if( skl/=one ) then
              call stdlib_slascl( joba, 0_ilp, 0_ilp, one, skl, m, n, a, lda, ierr )
              skl = one / skl
           end if
           ! row-cyclic jacobi svd algorithm with column pivoting
           emptsw = ( n*( n-1 ) ) / 2_ilp
           notrot = 0_ilp
           fastr( 1_ilp ) = zero
           ! a is represented in factored form a = a * diag(work), where diag(work)
           ! is initialized to identity. work is updated during fast scaled
           ! rotations.
           do q = 1, n
              work( q ) = one
           end do
           swband = 3_ilp
      ! [tp] swband is a tuning parameter [tp]. it is meaningful and effective
           ! if stdlib_sgesvj is used as a computational routine in the preconditioned
           ! jacobi svd algorithm stdlib_sgesvj. for sweeps i=1:swband the procedure
           ! works on pivots inside a band-like region around the diagonal.
           ! the boundaries are determined dynamically, based on the number of
           ! pivots above a threshold.
           kbl = min( 8_ilp, n )
      ! [tp] kbl is a tuning parameter that defines the tile size in the
           ! tiling of the p-q loops of pivot pairs. in general, an optimal
           ! value of kbl depends on the matrix dimensions and on the
           ! parameters of the computer's memory.
           nbl = n / kbl
           if( ( nbl*kbl )/=n )nbl = nbl + 1_ilp
           blskip = kbl**2_ilp
      ! [tp] blkskip is a tuning parameter that depends on swband and kbl.
           rowskip = min( 5_ilp, kbl )
      ! [tp] rowskip is a tuning parameter.
           lkahead = 1_ilp
      ! [tp] lkahead is a tuning parameter.
           ! quasi block transformations, using the lower (upper) triangular
           ! structure of the input matrix. the quasi-block-cycling usually
           ! invokes cubic convergence. big part of this cycle is done inside
           ! canonical subspaces of dimensions less than m.
           if( ( lower .or. upper ) .and. ( n>max( 64_ilp, 4_ilp*kbl ) ) ) then
      ! [tp] the number of partition levels and the actual partition are
           ! tuning parameters.
              n4 = n / 4_ilp
              n2 = n / 2_ilp
              n34 = 3_ilp*n4
              if( applv ) then
                 q = 0_ilp
              else
                 q = 1_ilp
              end if
              if( lower ) then
           ! this works very well on lower triangular matrices, in particular
           ! in the framework of the preconditioned jacobi svd (xgejsv).
           ! the idea is simple:
           ! [+ 0 0 0]   note that jacobi transformations of [0 0]
           ! [+ + 0 0]                                       [0 0]
           ! [+ + x 0]   actually work on [x 0]              [x 0]
           ! [+ + x x]                    [x x].             [x x]
                 call stdlib_sgsvj0( jobv, m-n34, n-n34, a( n34+1, n34+1 ), lda,work( n34+1 ), &
                 sva( n34+1 ), mvl,v( n34*q+1, n34+1 ), ldv, epsln, sfmin, tol,2_ilp, work( n+1 ), &
                           lwork-n, ierr )
                 call stdlib_sgsvj0( jobv, m-n2, n34-n2, a( n2+1, n2+1 ), lda,work( n2+1 ), sva( &
                 n2+1 ), mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 2_ilp,work( n+1 ), lwork-n, &
                           ierr )
                 call stdlib_sgsvj1( jobv, m-n2, n-n2, n4, a( n2+1, n2+1 ), lda,work( n2+1 ), sva(&
                  n2+1 ), mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 1_ilp,work( n+1 ), lwork-n, &
                            ierr )
                 call stdlib_sgsvj0( jobv, m-n4, n2-n4, a( n4+1, n4+1 ), lda,work( n4+1 ), sva( &
                 n4+1 ), mvl,v( n4*q+1, n4+1 ), ldv, epsln, sfmin, tol, 1_ilp,work( n+1 ), lwork-n, &
                           ierr )
                 call stdlib_sgsvj0( jobv, m, n4, a, lda, work, sva, mvl, v, ldv,epsln, sfmin, &
                           tol, 1_ilp, work( n+1 ), lwork-n,ierr )
                 call stdlib_sgsvj1( jobv, m, n2, n4, a, lda, work, sva, mvl, v,ldv, epsln, sfmin,&
                            tol, 1_ilp, work( n+1 ),lwork-n, ierr )
              else if( upper ) then
                 call stdlib_sgsvj0( jobv, n4, n4, a, lda, work, sva, mvl, v, ldv,epsln, sfmin, &
                           tol, 2_ilp, work( n+1 ), lwork-n,ierr )
                 call stdlib_sgsvj0( jobv, n2, n4, a( 1_ilp, n4+1 ), lda, work( n4+1 ),sva( n4+1 ), &
                 mvl, v( n4*q+1, n4+1 ), ldv,epsln, sfmin, tol, 1_ilp, work( n+1 ), lwork-n,ierr )
                           
                 call stdlib_sgsvj1( jobv, n2, n2, n4, a, lda, work, sva, mvl, v,ldv, epsln, &
                           sfmin, tol, 1_ilp, work( n+1 ),lwork-n, ierr )
                 call stdlib_sgsvj0( jobv, n2+n4, n4, a( 1_ilp, n2+1 ), lda,work( n2+1 ), sva( n2+1 ),&
                  mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 1_ilp,work( n+1 ), lwork-n, ierr )
                            
              end if
           end if
           ! .. row-cyclic pivot strategy with de rijk's pivoting ..
           loop_1993: do i = 1, nsweep
           ! .. go go go ...
              mxaapq = zero
              mxsinj = zero
              iswrot = 0_ilp
              notrot = 0_ilp
              pskipped = 0_ilp
           ! each sweep is unrolled using kbl-by-kbl tiles over the pivot pairs
           ! 1 <= p < q <= n. this is the first step toward a blocked implementation
           ! of the rotations. new implementation, based on block transformations,
           ! is under development.
              loop_2000: do ibr = 1, nbl
                 igl = ( ibr-1 )*kbl + 1_ilp
                 loop_1002: do ir1 = 0, min( lkahead, nbl-ibr )
                    igl = igl + ir1*kbl
                    loop_2001: do p = igl, min( igl+kbl-1, n-1 )
           ! .. de rijk's pivoting
                       q = stdlib_isamax( n-p+1, sva( p ), 1_ilp ) + p - 1_ilp
                       if( p/=q ) then
                          call stdlib_sswap( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp, q ), 1_ilp )
                          if( rsvec )call stdlib_sswap( mvl, v( 1_ilp, p ), 1_ilp,v( 1_ilp, q ), 1_ilp )
                          temp1 = sva( p )
                          sva( p ) = sva( q )
                          sva( q ) = temp1
                          temp1 = work( p )
                          work( p ) = work( q )
                          work( q ) = temp1
                       end if
                       if( ir1==0_ilp ) then
              ! column norms are periodically updated by explicit
              ! norm computation.
              ! caveat:
              ! unfortunately, some blas implementations compute stdlib_snrm2(m,a(1,p),1)
              ! as sqrt(stdlib_sdot(m,a(1,p),1,a(1,p),1)), which may cause the result to
              ! overflow for ||a(:,p)||_2 > sqrt(overflow_threshold), and to
              ! underflow for ||a(:,p)||_2 < sqrt(underflow_threshold).
              ! hence, stdlib_snrm2 cannot be trusted, not even in the case when
              ! the true norm is far from the under(over)flow boundaries.
              ! if properly implemented stdlib_snrm2 is available, the if-then-else
              ! below should read "aapp = stdlib_snrm2( m, a(1,p), 1 ) * work(p)".
                          if( ( sva( p )<rootbig ) .and.( sva( p )>rootsfmin ) ) then
                             sva( p ) = stdlib_snrm2( m, a( 1_ilp, p ), 1_ilp )*work( p )
                          else
                             temp1 = zero
                             aapp = one
                             call stdlib_slassq( m, a( 1_ilp, p ), 1_ilp, temp1, aapp )
                             sva( p ) = temp1*sqrt( aapp )*work( p )
                          end if
                          aapp = sva( p )
                       else
                          aapp = sva( p )
                       end if
                       if( aapp>zero ) then
                          pskipped = 0_ilp
                          loop_2002: do q = p + 1, min( igl+kbl-1, n )
                             aaqq = sva( q )
                             if( aaqq>zero ) then
                                aapp0 = aapp
                                if( aaqq>=one ) then
                                   rotok = ( small*aapp )<=aaqq
                                   if( aapp<( big / aaqq ) ) then
                                      aapq = ( stdlib_sdot( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp,q ), 1_ilp )*work( &
                                                p )*work( q ) /aaqq ) / aapp
                                   else
                                      call stdlib_scopy( m, a( 1_ilp, p ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_slascl( 'G', 0_ilp, 0_ilp, aapp,work( p ), m, 1_ilp,work( n+&
                                                1_ilp ), lda, ierr )
                                      aapq = stdlib_sdot( m, work( n+1 ), 1_ilp,a( 1_ilp, q ), 1_ilp )*work( &
                                                q ) / aaqq
                                   end if
                                else
                                   rotok = aapp<=( aaqq / small )
                                   if( aapp>( small / aaqq ) ) then
                                      aapq = ( stdlib_sdot( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp,q ), 1_ilp )*work( &
                                                p )*work( q ) /aaqq ) / aapp
                                   else
                                      call stdlib_scopy( m, a( 1_ilp, q ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_slascl( 'G', 0_ilp, 0_ilp, aaqq,work( q ), m, 1_ilp,work( n+&
                                                1_ilp ), lda, ierr )
                                      aapq = stdlib_sdot( m, work( n+1 ), 1_ilp,a( 1_ilp, p ), 1_ilp )*work( &
                                                p ) / aapp
                                   end if
                                end if
                                mxaapq = max( mxaapq, abs( aapq ) )
              ! to rotate or not to rotate, that is the question ...
                                if( abs( aapq )>tol ) then
                 ! Rotate
      ! [rtd]      rotated = rotated + one
                                   if( ir1==0_ilp ) then
                                      notrot = 0_ilp
                                      pskipped = 0_ilp
                                      iswrot = iswrot + 1_ilp
                                   end if
                                   if( rotok ) then
                                      aqoap = aaqq / aapp
                                      apoaq = aapp / aaqq
                                      theta = -half*abs( aqoap-apoaq ) / aapq
                                      if( abs( theta )>bigtheta ) then
                                         t = half / theta
                                         fastr( 3_ilp ) = t*work( p ) / work( q )
                                         fastr( 4_ilp ) = -t*work( q ) /work( p )
                                         call stdlib_srotm( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp, fastr )
                                                   
                                         if( rsvec )call stdlib_srotm( mvl,v( 1_ilp, p ), 1_ilp,v( 1_ilp, q ),&
                                                    1_ilp,fastr )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq ) )
                                         mxsinj = max( mxsinj, abs( t ) )
                                      else
                       ! Choose Correct Signum For Theta And Rotate
                                         thsign = -sign( one, aapq )
                                         t = one / ( theta+thsign*sqrt( one+theta*theta ) )
                                                   
                                         cs = sqrt( one / ( one+t*t ) )
                                         sn = t*cs
                                         mxsinj = max( mxsinj, abs( sn ) )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq ) )
                                         apoaq = work( p ) / work( q )
                                         aqoap = work( q ) / work( p )
                                         if( work( p )>=one ) then
                                            if( work( q )>=one ) then
                                               fastr( 3_ilp ) = t*apoaq
                                               fastr( 4_ilp ) = -t*aqoap
                                               work( p ) = work( p )*cs
                                               work( q ) = work( q )*cs
                                               call stdlib_srotm( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp,&
                                                         fastr )
                                               if( rsvec )call stdlib_srotm( mvl,v( 1_ilp, p ), 1_ilp, v( &
                                                         1_ilp, q ),1_ilp, fastr )
                                            else
                                               call stdlib_saxpy( m, -t*aqoap,a( 1_ilp, q ), 1_ilp,a( 1_ilp, &
                                                         p ), 1_ilp )
                                               call stdlib_saxpy( m, cs*sn*apoaq,a( 1_ilp, p ), 1_ilp,a( &
                                                         1_ilp, q ), 1_ilp )
                                               work( p ) = work( p )*cs
                                               work( q ) = work( q ) / cs
                                               if( rsvec ) then
                                                  call stdlib_saxpy( mvl, -t*aqoap,v( 1_ilp, q ), 1_ilp,v(&
                                                             1_ilp, p ), 1_ilp )
                                                  call stdlib_saxpy( mvl,cs*sn*apoaq,v( 1_ilp, p ), 1_ilp,&
                                                            v( 1_ilp, q ), 1_ilp )
                                               end if
                                            end if
                                         else
                                            if( work( q )>=one ) then
                                               call stdlib_saxpy( m, t*apoaq,a( 1_ilp, p ), 1_ilp,a( 1_ilp, q &
                                                         ), 1_ilp )
                                               call stdlib_saxpy( m, -cs*sn*aqoap,a( 1_ilp, q ), 1_ilp,a( &
                                                         1_ilp, p ), 1_ilp )
                                               work( p ) = work( p ) / cs
                                               work( q ) = work( q )*cs
                                               if( rsvec ) then
                                                  call stdlib_saxpy( mvl, t*apoaq,v( 1_ilp, p ), 1_ilp,v( &
                                                            1_ilp, q ), 1_ilp )
                                                  call stdlib_saxpy( mvl,-cs*sn*aqoap,v( 1_ilp, q ), &
                                                            1_ilp,v( 1_ilp, p ), 1_ilp )
                                               end if
                                            else
                                               if( work( p )>=work( q ) )then
                                                  call stdlib_saxpy( m, -t*aqoap,a( 1_ilp, q ), 1_ilp,a( &
                                                            1_ilp, p ), 1_ilp )
                                                  call stdlib_saxpy( m, cs*sn*apoaq,a( 1_ilp, p ), 1_ilp,&
                                                            a( 1_ilp, q ), 1_ilp )
                                                  work( p ) = work( p )*cs
                                                  work( q ) = work( q ) / cs
                                                  if( rsvec ) then
                                                     call stdlib_saxpy( mvl,-t*aqoap,v( 1_ilp, q ), 1_ilp,&
                                                               v( 1_ilp, p ), 1_ilp )
                                                     call stdlib_saxpy( mvl,cs*sn*apoaq,v( 1_ilp, p ),&
                                                                1_ilp,v( 1_ilp, q ), 1_ilp )
                                                  end if
                                               else
                                                  call stdlib_saxpy( m, t*apoaq,a( 1_ilp, p ), 1_ilp,a( 1_ilp,&
                                                             q ), 1_ilp )
                                                  call stdlib_saxpy( m,-cs*sn*aqoap,a( 1_ilp, q ), 1_ilp,&
                                                            a( 1_ilp, p ), 1_ilp )
                                                  work( p ) = work( p ) / cs
                                                  work( q ) = work( q )*cs
                                                  if( rsvec ) then
                                                     call stdlib_saxpy( mvl,t*apoaq, v( 1_ilp, p ),1_ilp, &
                                                               v( 1_ilp, q ), 1_ilp )
                                                     call stdlib_saxpy( mvl,-cs*sn*aqoap,v( 1_ilp, q )&
                                                               , 1_ilp,v( 1_ilp, p ), 1_ilp )
                                                  end if
                                               end if
                                            end if
                                         end if
                                      end if
                                   else
                    ! .. have to use modified gram-schmidt like transformation
                                      call stdlib_scopy( m, a( 1_ilp, p ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_slascl( 'G', 0_ilp, 0_ilp, aapp, one, m,1_ilp, work( n+1 ), &
                                                lda,ierr )
                                      call stdlib_slascl( 'G', 0_ilp, 0_ilp, aaqq, one, m,1_ilp, a( 1_ilp, q ), &
                                                lda, ierr )
                                      temp1 = -aapq*work( p ) / work( q )
                                      call stdlib_saxpy( m, temp1, work( n+1 ), 1_ilp,a( 1_ilp, q ), 1_ilp )
                                                
                                      call stdlib_slascl( 'G', 0_ilp, 0_ilp, one, aaqq, m,1_ilp, a( 1_ilp, q ), &
                                                lda, ierr )
                                      sva( q ) = aaqq*sqrt( max( zero,one-aapq*aapq ) )
                                      mxsinj = max( mxsinj, sfmin )
                                   end if
                 ! end if rotok then ... else
                 ! in the case of cancellation in updating sva(q), sva(p)
                 ! recompute sva(q), sva(p).
                                   if( ( sva( q ) / aaqq )**2_ilp<=rooteps )then
                                      if( ( aaqq<rootbig ) .and.( aaqq>rootsfmin ) ) then
                                         sva( q ) = stdlib_snrm2( m, a( 1_ilp, q ), 1_ilp )*work( q )
                                                   
                                      else
                                         t = zero
                                         aaqq = one
                                         call stdlib_slassq( m, a( 1_ilp, q ), 1_ilp, t,aaqq )
                                         sva( q ) = t*sqrt( aaqq )*work( q )
                                      end if
                                   end if
                                   if( ( aapp / aapp0 )<=rooteps ) then
                                      if( ( aapp<rootbig ) .and.( aapp>rootsfmin ) ) then
                                         aapp = stdlib_snrm2( m, a( 1_ilp, p ), 1_ilp )*work( p )
                                      else
                                         t = zero
                                         aapp = one
                                         call stdlib_slassq( m, a( 1_ilp, p ), 1_ilp, t,aapp )
                                         aapp = t*sqrt( aapp )*work( p )
                                      end if
                                      sva( p ) = aapp
                                   end if
                                else
              ! a(:,p) and a(:,q) already numerically orthogonal
                                   if( ir1==0_ilp )notrot = notrot + 1_ilp
      ! [rtd]      skipped  = skipped  + 1
                                   pskipped = pskipped + 1_ilp
                                end if
                             else
              ! a(:,q) is zero column
                                if( ir1==0_ilp )notrot = notrot + 1_ilp
                                pskipped = pskipped + 1_ilp
                             end if
                             if( ( i<=swband ) .and.( pskipped>rowskip ) ) then
                                if( ir1==0_ilp )aapp = -aapp
                                notrot = 0_ilp
                                go to 2103
                             end if
                          end do loop_2002
           ! end q-loop
           2103 continue
           ! bailed out of q-loop
                          sva( p ) = aapp
                       else
                          sva( p ) = aapp
                          if( ( ir1==0_ilp ) .and. ( aapp==zero ) )notrot = notrot + min( igl+kbl-1, &
                                    n ) - p
                       end if
                    end do loop_2001
           ! end of the p-loop
           ! end of doing the block ( ibr, ibr )
                 end do loop_1002
           ! end of ir1-loop
       ! ... go to the off diagonal blocks
                 igl = ( ibr-1 )*kbl + 1_ilp
                 loop_2010: do jbc = ibr + 1, nbl
                    jgl = ( jbc-1 )*kbl + 1_ilp
              ! doing the block at ( ibr, jbc )
                    ijblsk = 0_ilp
                    loop_2100: do p = igl, min( igl+kbl-1, n )
                       aapp = sva( p )
                       if( aapp>zero ) then
                          pskipped = 0_ilp
                          loop_2200: do q = jgl, min( jgl+kbl-1, n )
                             aaqq = sva( q )
                             if( aaqq>zero ) then
                                aapp0 = aapp
           ! M X 2 Jacobi Svd 
              ! safe gram matrix computation
                                if( aaqq>=one ) then
                                   if( aapp>=aaqq ) then
                                      rotok = ( small*aapp )<=aaqq
                                   else
                                      rotok = ( small*aaqq )<=aapp
                                   end if
                                   if( aapp<( big / aaqq ) ) then
                                      aapq = ( stdlib_sdot( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp,q ), 1_ilp )*work( &
                                                p )*work( q ) /aaqq ) / aapp
                                   else
                                      call stdlib_scopy( m, a( 1_ilp, p ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_slascl( 'G', 0_ilp, 0_ilp, aapp,work( p ), m, 1_ilp,work( n+&
                                                1_ilp ), lda, ierr )
                                      aapq = stdlib_sdot( m, work( n+1 ), 1_ilp,a( 1_ilp, q ), 1_ilp )*work( &
                                                q ) / aaqq
                                   end if
                                else
                                   if( aapp>=aaqq ) then
                                      rotok = aapp<=( aaqq / small )
                                   else
                                      rotok = aaqq<=( aapp / small )
                                   end if
                                   if( aapp>( small / aaqq ) ) then
                                      aapq = ( stdlib_sdot( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp,q ), 1_ilp )*work( &
                                                p )*work( q ) /aaqq ) / aapp
                                   else
                                      call stdlib_scopy( m, a( 1_ilp, q ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_slascl( 'G', 0_ilp, 0_ilp, aaqq,work( q ), m, 1_ilp,work( n+&
                                                1_ilp ), lda, ierr )
                                      aapq = stdlib_sdot( m, work( n+1 ), 1_ilp,a( 1_ilp, p ), 1_ilp )*work( &
                                                p ) / aapp
                                   end if
                                end if
                                mxaapq = max( mxaapq, abs( aapq ) )
              ! to rotate or not to rotate, that is the question ...
                                if( abs( aapq )>tol ) then
                                   notrot = 0_ilp
      ! [rtd]      rotated  = rotated + 1
                                   pskipped = 0_ilp
                                   iswrot = iswrot + 1_ilp
                                   if( rotok ) then
                                      aqoap = aaqq / aapp
                                      apoaq = aapp / aaqq
                                      theta = -half*abs( aqoap-apoaq ) / aapq
                                      if( aaqq>aapp0 )theta = -theta
                                      if( abs( theta )>bigtheta ) then
                                         t = half / theta
                                         fastr( 3_ilp ) = t*work( p ) / work( q )
                                         fastr( 4_ilp ) = -t*work( q ) /work( p )
                                         call stdlib_srotm( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp, fastr )
                                                   
                                         if( rsvec )call stdlib_srotm( mvl,v( 1_ilp, p ), 1_ilp,v( 1_ilp, q ),&
                                                    1_ilp,fastr )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq ) )
                                         mxsinj = max( mxsinj, abs( t ) )
                                      else
                       ! Choose Correct Signum For Theta And Rotate
                                         thsign = -sign( one, aapq )
                                         if( aaqq>aapp0 )thsign = -thsign
                                         t = one / ( theta+thsign*sqrt( one+theta*theta ) )
                                                   
                                         cs = sqrt( one / ( one+t*t ) )
                                         sn = t*cs
                                         mxsinj = max( mxsinj, abs( sn ) )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq ) )
                                         apoaq = work( p ) / work( q )
                                         aqoap = work( q ) / work( p )
                                         if( work( p )>=one ) then
                                            if( work( q )>=one ) then
                                               fastr( 3_ilp ) = t*apoaq
                                               fastr( 4_ilp ) = -t*aqoap
                                               work( p ) = work( p )*cs
                                               work( q ) = work( q )*cs
                                               call stdlib_srotm( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp,&
                                                         fastr )
                                               if( rsvec )call stdlib_srotm( mvl,v( 1_ilp, p ), 1_ilp, v( &
                                                         1_ilp, q ),1_ilp, fastr )
                                            else
                                               call stdlib_saxpy( m, -t*aqoap,a( 1_ilp, q ), 1_ilp,a( 1_ilp, &
                                                         p ), 1_ilp )
                                               call stdlib_saxpy( m, cs*sn*apoaq,a( 1_ilp, p ), 1_ilp,a( &
                                                         1_ilp, q ), 1_ilp )
                                               if( rsvec ) then
                                                  call stdlib_saxpy( mvl, -t*aqoap,v( 1_ilp, q ), 1_ilp,v(&
                                                             1_ilp, p ), 1_ilp )
                                                  call stdlib_saxpy( mvl,cs*sn*apoaq,v( 1_ilp, p ), 1_ilp,&
                                                            v( 1_ilp, q ), 1_ilp )
                                               end if
                                               work( p ) = work( p )*cs
                                               work( q ) = work( q ) / cs
                                            end if
                                         else
                                            if( work( q )>=one ) then
                                               call stdlib_saxpy( m, t*apoaq,a( 1_ilp, p ), 1_ilp,a( 1_ilp, q &
                                                         ), 1_ilp )
                                               call stdlib_saxpy( m, -cs*sn*aqoap,a( 1_ilp, q ), 1_ilp,a( &
                                                         1_ilp, p ), 1_ilp )
                                               if( rsvec ) then
                                                  call stdlib_saxpy( mvl, t*apoaq,v( 1_ilp, p ), 1_ilp,v( &
                                                            1_ilp, q ), 1_ilp )
                                                  call stdlib_saxpy( mvl,-cs*sn*aqoap,v( 1_ilp, q ), &
                                                            1_ilp,v( 1_ilp, p ), 1_ilp )
                                               end if
                                               work( p ) = work( p ) / cs
                                               work( q ) = work( q )*cs
                                            else
                                               if( work( p )>=work( q ) )then
                                                  call stdlib_saxpy( m, -t*aqoap,a( 1_ilp, q ), 1_ilp,a( &
                                                            1_ilp, p ), 1_ilp )
                                                  call stdlib_saxpy( m, cs*sn*apoaq,a( 1_ilp, p ), 1_ilp,&
                                                            a( 1_ilp, q ), 1_ilp )
                                                  work( p ) = work( p )*cs
                                                  work( q ) = work( q ) / cs
                                                  if( rsvec ) then
                                                     call stdlib_saxpy( mvl,-t*aqoap,v( 1_ilp, q ), 1_ilp,&
                                                               v( 1_ilp, p ), 1_ilp )
                                                     call stdlib_saxpy( mvl,cs*sn*apoaq,v( 1_ilp, p ),&
                                                                1_ilp,v( 1_ilp, q ), 1_ilp )
                                                  end if
                                               else
                                                  call stdlib_saxpy( m, t*apoaq,a( 1_ilp, p ), 1_ilp,a( 1_ilp,&
                                                             q ), 1_ilp )
                                                  call stdlib_saxpy( m,-cs*sn*aqoap,a( 1_ilp, q ), 1_ilp,&
                                                            a( 1_ilp, p ), 1_ilp )
                                                  work( p ) = work( p ) / cs
                                                  work( q ) = work( q )*cs
                                                  if( rsvec ) then
                                                     call stdlib_saxpy( mvl,t*apoaq, v( 1_ilp, p ),1_ilp, &
                                                               v( 1_ilp, q ), 1_ilp )
                                                     call stdlib_saxpy( mvl,-cs*sn*aqoap,v( 1_ilp, q )&
                                                               , 1_ilp,v( 1_ilp, p ), 1_ilp )
                                                  end if
                                               end if
                                            end if
                                         end if
                                      end if
                                   else
                                      if( aapp>aaqq ) then
                                         call stdlib_scopy( m, a( 1_ilp, p ), 1_ilp,work( n+1 ), 1_ilp )
                                                   
                                         call stdlib_slascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, work( n+1 &
                                                   ), lda,ierr )
                                         call stdlib_slascl( 'G', 0_ilp, 0_ilp, aaqq, one,m, 1_ilp, a( 1_ilp, q ),&
                                                    lda,ierr )
                                         temp1 = -aapq*work( p ) / work( q )
                                         call stdlib_saxpy( m, temp1, work( n+1 ),1_ilp, a( 1_ilp, q ), 1_ilp &
                                                   )
                                         call stdlib_slascl( 'G', 0_ilp, 0_ilp, one, aaqq,m, 1_ilp, a( 1_ilp, q ),&
                                                    lda,ierr )
                                         sva( q ) = aaqq*sqrt( max( zero,one-aapq*aapq ) )
                                         mxsinj = max( mxsinj, sfmin )
                                      else
                                         call stdlib_scopy( m, a( 1_ilp, q ), 1_ilp,work( n+1 ), 1_ilp )
                                                   
                                         call stdlib_slascl( 'G', 0_ilp, 0_ilp, aaqq, one,m, 1_ilp, work( n+1 &
                                                   ), lda,ierr )
                                         call stdlib_slascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, a( 1_ilp, p ),&
                                                    lda,ierr )
                                         temp1 = -aapq*work( q ) / work( p )
                                         call stdlib_saxpy( m, temp1, work( n+1 ),1_ilp, a( 1_ilp, p ), 1_ilp &
                                                   )
                                         call stdlib_slascl( 'G', 0_ilp, 0_ilp, one, aapp,m, 1_ilp, a( 1_ilp, p ),&
                                                    lda,ierr )
                                         sva( p ) = aapp*sqrt( max( zero,one-aapq*aapq ) )
                                         mxsinj = max( mxsinj, sfmin )
                                      end if
                                   end if
                 ! end if rotok then ... else
                 ! in the case of cancellation in updating sva(q)
                 ! .. recompute sva(q)
                                   if( ( sva( q ) / aaqq )**2_ilp<=rooteps )then
                                      if( ( aaqq<rootbig ) .and.( aaqq>rootsfmin ) ) then
                                         sva( q ) = stdlib_snrm2( m, a( 1_ilp, q ), 1_ilp )*work( q )
                                                   
                                      else
                                         t = zero
                                         aaqq = one
                                         call stdlib_slassq( m, a( 1_ilp, q ), 1_ilp, t,aaqq )
                                         sva( q ) = t*sqrt( aaqq )*work( q )
                                      end if
                                   end if
                                   if( ( aapp / aapp0 )**2_ilp<=rooteps ) then
                                      if( ( aapp<rootbig ) .and.( aapp>rootsfmin ) ) then
                                         aapp = stdlib_snrm2( m, a( 1_ilp, p ), 1_ilp )*work( p )
                                      else
                                         t = zero
                                         aapp = one
                                         call stdlib_slassq( m, a( 1_ilp, p ), 1_ilp, t,aapp )
                                         aapp = t*sqrt( aapp )*work( p )
                                      end if
                                      sva( p ) = aapp
                                   end if
                    ! end of ok rotation
                                else
                                   notrot = notrot + 1_ilp
      ! [rtd]      skipped  = skipped  + 1
                                   pskipped = pskipped + 1_ilp
                                   ijblsk = ijblsk + 1_ilp
                                end if
                             else
                                notrot = notrot + 1_ilp
                                pskipped = pskipped + 1_ilp
                                ijblsk = ijblsk + 1_ilp
                             end if
                             if( ( i<=swband ) .and. ( ijblsk>=blskip ) )then
                                sva( p ) = aapp
                                notrot = 0_ilp
                                go to 2011
                             end if
                             if( ( i<=swband ) .and.( pskipped>rowskip ) ) then
                                aapp = -aapp
                                notrot = 0_ilp
                                go to 2203
                             end if
                          end do loop_2200
              ! end of the q-loop
              2203 continue
                          sva( p ) = aapp
                       else
                          if( aapp==zero )notrot = notrot +min( jgl+kbl-1, n ) - jgl + 1_ilp
                          if( aapp<zero )notrot = 0_ilp
                       end if
                    end do loop_2100
           ! end of the p-loop
                 end do loop_2010
           ! end of the jbc-loop
           2011 continue
      ! 2011 bailed out of the jbc-loop
                 do p = igl, min( igl+kbl-1, n )
                    sva( p ) = abs( sva( p ) )
                 end do
      ! **
              end do loop_2000
      ! 2000 :: end of the ibr-loop
           ! .. update sva(n)
              if( ( sva( n )<rootbig ) .and. ( sva( n )>rootsfmin ) )then
                 sva( n ) = stdlib_snrm2( m, a( 1_ilp, n ), 1_ilp )*work( n )
              else
                 t = zero
                 aapp = one
                 call stdlib_slassq( m, a( 1_ilp, n ), 1_ilp, t, aapp )
                 sva( n ) = t*sqrt( aapp )*work( n )
              end if
           ! additional steering devices
              if( ( i<swband ) .and. ( ( mxaapq<=roottol ) .or.( iswrot<=n ) ) )swband = i
              if( ( i>swband+1 ) .and. ( mxaapq<sqrt( real( n,KIND=sp) )*tol ) .and. ( real( n,&
                        KIND=sp)*mxaapq*mxsinj<tol ) ) then
                 go to 1994
              end if
              if( notrot>=emptsw )go to 1994
           end do loop_1993
           ! end i=1:nsweep loop
       ! #:( reaching this point means that the procedure has not converged.
           info = nsweep - 1_ilp
           go to 1995
           1994 continue
       ! #:) reaching this point means numerical convergence after the i-th
           ! sweep.
           info = 0_ilp
       ! #:) info = 0 confirms successful iterations.
       1995 continue
           ! sort the singular values and find how many are above
           ! the underflow threshold.
           n2 = 0_ilp
           n4 = 0_ilp
           do p = 1, n - 1
              q = stdlib_isamax( n-p+1, sva( p ), 1_ilp ) + p - 1_ilp
              if( p/=q ) then
                 temp1 = sva( p )
                 sva( p ) = sva( q )
                 sva( q ) = temp1
                 temp1 = work( p )
                 work( p ) = work( q )
                 work( q ) = temp1
                 call stdlib_sswap( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp, q ), 1_ilp )
                 if( rsvec )call stdlib_sswap( mvl, v( 1_ilp, p ), 1_ilp, v( 1_ilp, q ), 1_ilp )
              end if
              if( sva( p )/=zero ) then
                 n4 = n4 + 1_ilp
                 if( sva( p )*skl>sfmin )n2 = n2 + 1_ilp
              end if
           end do
           if( sva( n )/=zero ) then
              n4 = n4 + 1_ilp
              if( sva( n )*skl>sfmin )n2 = n2 + 1_ilp
           end if
           ! normalize the left singular vectors.
           if( lsvec .or. uctol ) then
              do p = 1, n2
                 call stdlib_sscal( m, work( p ) / sva( p ), a( 1_ilp, p ), 1_ilp )
              end do
           end if
           ! scale the product of jacobi rotations (assemble the fast rotations).
           if( rsvec ) then
              if( applv ) then
                 do p = 1, n
                    call stdlib_sscal( mvl, work( p ), v( 1_ilp, p ), 1_ilp )
                 end do
              else
                 do p = 1, n
                    temp1 = one / stdlib_snrm2( mvl, v( 1_ilp, p ), 1_ilp )
                    call stdlib_sscal( mvl, temp1, v( 1_ilp, p ), 1_ilp )
                 end do
              end if
           end if
           ! undo scaling, if necessary (and possible).
           if( ( ( skl>one ) .and. ( sva( 1_ilp )<( big / skl ) ) ).or. ( ( skl<one ) .and. ( sva( &
                     max( n2, 1_ilp ) ) >( sfmin / skl ) ) ) ) then
              do p = 1, n
                 sva( p ) = skl*sva( p )
              end do
              skl = one
           end if
           work( 1_ilp ) = skl
           ! the singular values of a are skl*sva(1:n). if skl/=one
           ! then some of the singular values may overflow or underflow and
           ! the spectrum is given in this factored representation.
           work( 2_ilp ) = real( n4,KIND=sp)
           ! n4 is the number of computed nonzero singular values of a.
           work( 3_ilp ) = real( n2,KIND=sp)
           ! n2 is the number of singular values of a greater than sfmin.
           ! if n2<n, sva(n2:n) contains zeros and/or denormalized numbers
           ! that may carry some information.
           work( 4_ilp ) = real( i,KIND=sp)
           ! i is the index of the last sweep before declaring convergence.
           work( 5_ilp ) = mxaapq
           ! mxaapq is the largest absolute value of scaled pivots in the
           ! last sweep
           work( 6_ilp ) = mxsinj
           ! mxsinj is the largest absolute value of the sines of jacobi angles
           ! in the last sweep
           return
     end subroutine stdlib_sgesvj

     pure module subroutine stdlib_dgesvj( joba, jobu, jobv, m, n, a, lda, sva, mv, v,ldv, work, lwork, &
     !! DGESVJ computes the singular value decomposition (SVD) of a real
     !! M-by-N matrix A, where M >= N. The SVD of A is written as
     !! [++]   [xx]   [x0]   [xx]
     !! A = U * SIGMA * V^t,  [++] = [xx] * [ox] * [xx]
     !! [++]   [xx]
     !! where SIGMA is an N-by-N diagonal matrix, U is an M-by-N orthonormal
     !! matrix, and V is an N-by-N orthogonal matrix. The diagonal elements
     !! of SIGMA are the singular values of A. The columns of U and V are the
     !! left and the right singular vectors of A, respectively.
     !! DGESVJ can sometimes compute tiny singular values and their singular vectors much
     !! more accurately than other SVD routines, see below under Further Details.
               info )
        ! -- lapack computational routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_dp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldv, lwork, m, mv, n
           character, intent(in) :: joba, jobu, jobv
           ! Array Arguments 
           real(dp), intent(inout) :: a(lda,*), v(ldv,*), work(lwork)
           real(dp), intent(out) :: sva(n)
        ! =====================================================================
           ! Local Parameters 
           integer(ilp), parameter :: nsweep = 30_ilp
           
           
           ! Local Scalars 
           real(dp) :: aapp, aapp0, aapq, aaqq, apoaq, aqoap, big, bigtheta, cs, ctol, epsln, &
           large, mxaapq, mxsinj, rootbig, rooteps, rootsfmin, roottol, skl, sfmin, small, sn, t, &
                     temp1, theta, thsign, tol
           integer(ilp) :: blskip, emptsw, i, ibr, ierr, igl, ijblsk, ir1, iswrot, jbc, jgl, kbl, &
                     lkahead, mvl, n2, n34, n4, nbl, notrot, p, pskipped, q, rowskip, swband
           logical(lk) :: applv, goscale, lower, lsvec, noscale, rotok, rsvec, uctol, &
                     upper
           ! Local Arrays 
           real(dp) :: fastr(5_ilp)
           ! Intrinsic Functions 
           ! from lapack
           ! from lapack
           ! Executable Statements 
           ! test the input arguments
           lsvec = stdlib_lsame( jobu, 'U' )
           uctol = stdlib_lsame( jobu, 'C' )
           rsvec = stdlib_lsame( jobv, 'V' )
           applv = stdlib_lsame( jobv, 'A' )
           upper = stdlib_lsame( joba, 'U' )
           lower = stdlib_lsame( joba, 'L' )
           if( .not.( upper .or. lower .or. stdlib_lsame( joba, 'G' ) ) ) then
              info = -1_ilp
           else if( .not.( lsvec .or. uctol .or. stdlib_lsame( jobu, 'N' ) ) ) then
              info = -2_ilp
           else if( .not.( rsvec .or. applv .or. stdlib_lsame( jobv, 'N' ) ) ) then
              info = -3_ilp
           else if( m<0_ilp ) then
              info = -4_ilp
           else if( ( n<0_ilp ) .or. ( n>m ) ) then
              info = -5_ilp
           else if( lda<m ) then
              info = -7_ilp
           else if( mv<0_ilp ) then
              info = -9_ilp
           else if( ( rsvec .and. ( ldv<n ) ) .or.( applv .and. ( ldv<mv ) ) ) then
              info = -11_ilp
           else if( uctol .and. ( work( 1_ilp )<=one ) ) then
              info = -12_ilp
           else if( lwork<max( m+n, 6_ilp ) ) then
              info = -13_ilp
           else
              info = 0_ilp
           end if
           ! #:(
           if( info/=0_ilp ) then
              call stdlib_xerbla( 'DGESVJ', -info )
              return
           end if
       ! #:) quick return for void matrix
           if( ( m==0 ) .or. ( n==0 ) )return
           ! set numerical parameters
           ! the stopping criterion for jacobi rotations is
           ! max_{i<>j}|a(:,i)^t * a(:,j)|/(||a(:,i)||*||a(:,j)||) < ctol*eps
           ! where eps is the round-off and ctol is defined as follows:
           if( uctol ) then
              ! ... user controlled
              ctol = work( 1_ilp )
           else
              ! ... default
              if( lsvec .or. rsvec .or. applv ) then
                 ctol = sqrt( real( m,KIND=dp) )
              else
                 ctol = real( m,KIND=dp)
              end if
           end if
           ! ... and the machine dependent parameters are
      ! [!]  (make sure that stdlib_dlamch() works properly on the target machine.)
           epsln = stdlib_dlamch( 'EPSILON' )
           rooteps = sqrt( epsln )
           sfmin = stdlib_dlamch( 'SAFEMINIMUM' )
           rootsfmin = sqrt( sfmin )
           small = sfmin / epsln
           big = stdlib_dlamch( 'OVERFLOW' )
           ! big         = one    / sfmin
           rootbig = one / rootsfmin
           large = big / sqrt( real( m*n,KIND=dp) )
           bigtheta = one / rooteps
           tol = ctol*epsln
           roottol = sqrt( tol )
           if( real( m,KIND=dp)*epsln>=one ) then
              info = -4_ilp
              call stdlib_xerbla( 'DGESVJ', -info )
              return
           end if
           ! initialize the right singular vector matrix.
           if( rsvec ) then
              mvl = n
              call stdlib_dlaset( 'A', mvl, n, zero, one, v, ldv )
           else if( applv ) then
              mvl = mv
           end if
           rsvec = rsvec .or. applv
           ! initialize sva( 1:n ) = ( ||a e_i||_2, i = 1:n )
      ! (!)  if necessary, scale a to protect the largest singular value
           ! from overflow. it is possible that saving the largest singular
           ! value destroys the information about the small ones.
           ! this initial scaling is almost minimal in the sense that the
           ! goal is to make sure that no column norm overflows, and that
           ! sqrt(n)*max_i sva(i) does not overflow. if infinite entries
           ! in a are detected, the procedure returns with info=-6.
           skl= one / sqrt( real( m,KIND=dp)*real( n,KIND=dp) )
           noscale = .true.
           goscale = .true.
           if( lower ) then
              ! the input matrix is m-by-n lower triangular (trapezoidal)
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_dlassq( m-p+1, a( p, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'DGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl)
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           else if( upper ) then
              ! the input matrix is m-by-n upper triangular (trapezoidal)
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_dlassq( p, a( 1_ilp, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'DGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl)
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           else
              ! the input matrix is m-by-n general dense
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_dlassq( m, a( 1_ilp, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'DGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl)
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           end if
           if( noscale )skl= one
           ! move the smaller part of the spectrum from the underflow threshold
      ! (!)  start by determining the position of the nonzero entries of the
           ! array sva() relative to ( sfmin, big ).
           aapp = zero
           aaqq = big
           do p = 1, n
              if( sva( p )/=zero )aaqq = min( aaqq, sva( p ) )
              aapp = max( aapp, sva( p ) )
           end do
       ! #:) quick return for zero matrix
           if( aapp==zero ) then
              if( lsvec )call stdlib_dlaset( 'G', m, n, zero, one, a, lda )
              work( 1_ilp ) = one
              work( 2_ilp ) = zero
              work( 3_ilp ) = zero
              work( 4_ilp ) = zero
              work( 5_ilp ) = zero
              work( 6_ilp ) = zero
              return
           end if
       ! #:) quick return for one-column matrix
           if( n==1_ilp ) then
              if( lsvec )call stdlib_dlascl( 'G', 0_ilp, 0_ilp, sva( 1_ilp ), skl, m, 1_ilp,a( 1_ilp, 1_ilp ), lda, ierr )
                        
              work( 1_ilp ) = one / skl
              if( sva( 1_ilp )>=sfmin ) then
                 work( 2_ilp ) = one
              else
                 work( 2_ilp ) = zero
              end if
              work( 3_ilp ) = zero
              work( 4_ilp ) = zero
              work( 5_ilp ) = zero
              work( 6_ilp ) = zero
              return
           end if
           ! protect small singular values from underflow, and try to
           ! avoid underflows/overflows in computing jacobi rotations.
           sn = sqrt( sfmin / epsln )
           temp1 = sqrt( big / real( n,KIND=dp) )
           if( ( aapp<=sn ) .or. ( aaqq>=temp1 ) .or.( ( sn<=aaqq ) .and. ( aapp<=temp1 ) ) ) &
                     then
              temp1 = min( big, temp1 / aapp )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq<=sn ) .and. ( aapp<=temp1 ) ) then
              temp1 = min( sn / aaqq, big / ( aapp*sqrt( real( n,KIND=dp) ) ) )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq>=sn ) .and. ( aapp>=temp1 ) ) then
              temp1 = max( sn / aaqq, temp1 / aapp )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq<=sn ) .and. ( aapp>=temp1 ) ) then
              temp1 = min( sn / aaqq, big / ( sqrt( real( n,KIND=dp) )*aapp ) )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else
              temp1 = one
           end if
           ! scale, if necessary
           if( temp1/=one ) then
              call stdlib_dlascl( 'G', 0_ilp, 0_ilp, one, temp1, n, 1_ilp, sva, n, ierr )
           end if
           skl= temp1*skl
           if( skl/=one ) then
              call stdlib_dlascl( joba, 0_ilp, 0_ilp, one, skl, m, n, a, lda, ierr )
              skl= one / skl
           end if
           ! row-cyclic jacobi svd algorithm with column pivoting
           emptsw = ( n*( n-1 ) ) / 2_ilp
           notrot = 0_ilp
           fastr( 1_ilp ) = zero
           ! a is represented in factored form a = a * diag(work), where diag(work)
           ! is initialized to identity. work is updated during fast scaled
           ! rotations.
           do q = 1, n
              work( q ) = one
           end do
           swband = 3_ilp
      ! [tp] swband is a tuning parameter [tp]. it is meaningful and effective
           ! if stdlib_dgesvj is used as a computational routine in the preconditioned
           ! jacobi svd algorithm stdlib_dgesvj. for sweeps i=1:swband the procedure
           ! works on pivots inside a band-like region around the diagonal.
           ! the boundaries are determined dynamically, based on the number of
           ! pivots above a threshold.
           kbl = min( 8_ilp, n )
      ! [tp] kbl is a tuning parameter that defines the tile size in the
           ! tiling of the p-q loops of pivot pairs. in general, an optimal
           ! value of kbl depends on the matrix dimensions and on the
           ! parameters of the computer's memory.
           nbl = n / kbl
           if( ( nbl*kbl )/=n )nbl = nbl + 1_ilp
           blskip = kbl**2_ilp
      ! [tp] blkskip is a tuning parameter that depends on swband and kbl.
           rowskip = min( 5_ilp, kbl )
      ! [tp] rowskip is a tuning parameter.
           lkahead = 1_ilp
      ! [tp] lkahead is a tuning parameter.
           ! quasi block transformations, using the lower (upper) triangular
           ! structure of the input matrix. the quasi-block-cycling usually
           ! invokes cubic convergence. big part of this cycle is done inside
           ! canonical subspaces of dimensions less than m.
           if( ( lower .or. upper ) .and. ( n>max( 64_ilp, 4_ilp*kbl ) ) ) then
      ! [tp] the number of partition levels and the actual partition are
           ! tuning parameters.
              n4 = n / 4_ilp
              n2 = n / 2_ilp
              n34 = 3_ilp*n4
              if( applv ) then
                 q = 0_ilp
              else
                 q = 1_ilp
              end if
              if( lower ) then
           ! this works very well on lower triangular matrices, in particular
           ! in the framework of the preconditioned jacobi svd (xgejsv).
           ! the idea is simple:
           ! [+ 0 0 0]   note that jacobi transformations of [0 0]
           ! [+ + 0 0]                                       [0 0]
           ! [+ + x 0]   actually work on [x 0]              [x 0]
           ! [+ + x x]                    [x x].             [x x]
                 call stdlib_dgsvj0( jobv, m-n34, n-n34, a( n34+1, n34+1 ), lda,work( n34+1 ), &
                 sva( n34+1 ), mvl,v( n34*q+1, n34+1 ), ldv, epsln, sfmin, tol,2_ilp, work( n+1 ), &
                           lwork-n, ierr )
                 call stdlib_dgsvj0( jobv, m-n2, n34-n2, a( n2+1, n2+1 ), lda,work( n2+1 ), sva( &
                 n2+1 ), mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 2_ilp,work( n+1 ), lwork-n, &
                           ierr )
                 call stdlib_dgsvj1( jobv, m-n2, n-n2, n4, a( n2+1, n2+1 ), lda,work( n2+1 ), sva(&
                  n2+1 ), mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 1_ilp,work( n+1 ), lwork-n, &
                            ierr )
                 call stdlib_dgsvj0( jobv, m-n4, n2-n4, a( n4+1, n4+1 ), lda,work( n4+1 ), sva( &
                 n4+1 ), mvl,v( n4*q+1, n4+1 ), ldv, epsln, sfmin, tol, 1_ilp,work( n+1 ), lwork-n, &
                           ierr )
                 call stdlib_dgsvj0( jobv, m, n4, a, lda, work, sva, mvl, v, ldv,epsln, sfmin, &
                           tol, 1_ilp, work( n+1 ), lwork-n,ierr )
                 call stdlib_dgsvj1( jobv, m, n2, n4, a, lda, work, sva, mvl, v,ldv, epsln, sfmin,&
                            tol, 1_ilp, work( n+1 ),lwork-n, ierr )
              else if( upper ) then
                 call stdlib_dgsvj0( jobv, n4, n4, a, lda, work, sva, mvl, v, ldv,epsln, sfmin, &
                           tol, 2_ilp, work( n+1 ), lwork-n,ierr )
                 call stdlib_dgsvj0( jobv, n2, n4, a( 1_ilp, n4+1 ), lda, work( n4+1 ),sva( n4+1 ), &
                 mvl, v( n4*q+1, n4+1 ), ldv,epsln, sfmin, tol, 1_ilp, work( n+1 ), lwork-n,ierr )
                           
                 call stdlib_dgsvj1( jobv, n2, n2, n4, a, lda, work, sva, mvl, v,ldv, epsln, &
                           sfmin, tol, 1_ilp, work( n+1 ),lwork-n, ierr )
                 call stdlib_dgsvj0( jobv, n2+n4, n4, a( 1_ilp, n2+1 ), lda,work( n2+1 ), sva( n2+1 ),&
                  mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 1_ilp,work( n+1 ), lwork-n, ierr )
                            
              end if
           end if
           ! .. row-cyclic pivot strategy with de rijk's pivoting ..
           loop_1993: do i = 1, nsweep
           ! .. go go go ...
              mxaapq = zero
              mxsinj = zero
              iswrot = 0_ilp
              notrot = 0_ilp
              pskipped = 0_ilp
           ! each sweep is unrolled using kbl-by-kbl tiles over the pivot pairs
           ! 1 <= p < q <= n. this is the first step toward a blocked implementation
           ! of the rotations. new implementation, based on block transformations,
           ! is under development.
              loop_2000: do ibr = 1, nbl
                 igl = ( ibr-1 )*kbl + 1_ilp
                 loop_1002: do ir1 = 0, min( lkahead, nbl-ibr )
                    igl = igl + ir1*kbl
                    loop_2001: do p = igl, min( igl+kbl-1, n-1 )
           ! .. de rijk's pivoting
                       q = stdlib_idamax( n-p+1, sva( p ), 1_ilp ) + p - 1_ilp
                       if( p/=q ) then
                          call stdlib_dswap( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp, q ), 1_ilp )
                          if( rsvec )call stdlib_dswap( mvl, v( 1_ilp, p ), 1_ilp,v( 1_ilp, q ), 1_ilp )
                          temp1 = sva( p )
                          sva( p ) = sva( q )
                          sva( q ) = temp1
                          temp1 = work( p )
                          work( p ) = work( q )
                          work( q ) = temp1
                       end if
                       if( ir1==0_ilp ) then
              ! column norms are periodically updated by explicit
              ! norm computation.
              ! caveat:
              ! unfortunately, some blas implementations compute stdlib_dnrm2(m,a(1,p),1)
              ! as sqrt(stdlib_ddot(m,a(1,p),1,a(1,p),1)), which may cause the result to
              ! overflow for ||a(:,p)||_2 > sqrt(overflow_threshold), and to
              ! underflow for ||a(:,p)||_2 < sqrt(underflow_threshold).
              ! hence, stdlib_dnrm2 cannot be trusted, not even in the case when
              ! the true norm is far from the under(over)flow boundaries.
              ! if properly implemented stdlib_dnrm2 is available, the if-then-else
              ! below should read "aapp = stdlib_dnrm2( m, a(1,p), 1 ) * work(p)".
                          if( ( sva( p )<rootbig ) .and.( sva( p )>rootsfmin ) ) then
                             sva( p ) = stdlib_dnrm2( m, a( 1_ilp, p ), 1_ilp )*work( p )
                          else
                             temp1 = zero
                             aapp = one
                             call stdlib_dlassq( m, a( 1_ilp, p ), 1_ilp, temp1, aapp )
                             sva( p ) = temp1*sqrt( aapp )*work( p )
                          end if
                          aapp = sva( p )
                       else
                          aapp = sva( p )
                       end if
                       if( aapp>zero ) then
                          pskipped = 0_ilp
                          loop_2002: do q = p + 1, min( igl+kbl-1, n )
                             aaqq = sva( q )
                             if( aaqq>zero ) then
                                aapp0 = aapp
                                if( aaqq>=one ) then
                                   rotok = ( small*aapp )<=aaqq
                                   if( aapp<( big / aaqq ) ) then
                                      aapq = ( stdlib_ddot( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp,q ), 1_ilp )*work( &
                                                p )*work( q ) /aaqq ) / aapp
                                   else
                                      call stdlib_dcopy( m, a( 1_ilp, p ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aapp,work( p ), m, 1_ilp,work( n+&
                                                1_ilp ), lda, ierr )
                                      aapq = stdlib_ddot( m, work( n+1 ), 1_ilp,a( 1_ilp, q ), 1_ilp )*work( &
                                                q ) / aaqq
                                   end if
                                else
                                   rotok = aapp<=( aaqq / small )
                                   if( aapp>( small / aaqq ) ) then
                                      aapq = ( stdlib_ddot( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp,q ), 1_ilp )*work( &
                                                p )*work( q ) /aaqq ) / aapp
                                   else
                                      call stdlib_dcopy( m, a( 1_ilp, q ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aaqq,work( q ), m, 1_ilp,work( n+&
                                                1_ilp ), lda, ierr )
                                      aapq = stdlib_ddot( m, work( n+1 ), 1_ilp,a( 1_ilp, p ), 1_ilp )*work( &
                                                p ) / aapp
                                   end if
                                end if
                                mxaapq = max( mxaapq, abs( aapq ) )
              ! to rotate or not to rotate, that is the question ...
                                if( abs( aapq )>tol ) then
                 ! Rotate
      ! [rtd]      rotated = rotated + one
                                   if( ir1==0_ilp ) then
                                      notrot = 0_ilp
                                      pskipped = 0_ilp
                                      iswrot = iswrot + 1_ilp
                                   end if
                                   if( rotok ) then
                                      aqoap = aaqq / aapp
                                      apoaq = aapp / aaqq
                                      theta = -half*abs(aqoap-apoaq)/aapq
                                      if( abs( theta )>bigtheta ) then
                                         t = half / theta
                                         fastr( 3_ilp ) = t*work( p ) / work( q )
                                         fastr( 4_ilp ) = -t*work( q ) /work( p )
                                         call stdlib_drotm( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp, fastr )
                                                   
                                         if( rsvec )call stdlib_drotm( mvl,v( 1_ilp, p ), 1_ilp,v( 1_ilp, q ),&
                                                    1_ilp,fastr )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq ) )
                                         mxsinj = max( mxsinj, abs( t ) )
                                      else
                       ! Choose Correct Signum For Theta And Rotate
                                         thsign = -sign( one, aapq )
                                         t = one / ( theta+thsign*sqrt( one+theta*theta ) )
                                                   
                                         cs = sqrt( one / ( one+t*t ) )
                                         sn = t*cs
                                         mxsinj = max( mxsinj, abs( sn ) )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq ) )
                                         apoaq = work( p ) / work( q )
                                         aqoap = work( q ) / work( p )
                                         if( work( p )>=one ) then
                                            if( work( q )>=one ) then
                                               fastr( 3_ilp ) = t*apoaq
                                               fastr( 4_ilp ) = -t*aqoap
                                               work( p ) = work( p )*cs
                                               work( q ) = work( q )*cs
                                               call stdlib_drotm( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp,&
                                                         fastr )
                                               if( rsvec )call stdlib_drotm( mvl,v( 1_ilp, p ), 1_ilp, v( &
                                                         1_ilp, q ),1_ilp, fastr )
                                            else
                                               call stdlib_daxpy( m, -t*aqoap,a( 1_ilp, q ), 1_ilp,a( 1_ilp, &
                                                         p ), 1_ilp )
                                               call stdlib_daxpy( m, cs*sn*apoaq,a( 1_ilp, p ), 1_ilp,a( &
                                                         1_ilp, q ), 1_ilp )
                                               work( p ) = work( p )*cs
                                               work( q ) = work( q ) / cs
                                               if( rsvec ) then
                                                  call stdlib_daxpy( mvl, -t*aqoap,v( 1_ilp, q ), 1_ilp,v(&
                                                             1_ilp, p ), 1_ilp )
                                                  call stdlib_daxpy( mvl,cs*sn*apoaq,v( 1_ilp, p ), 1_ilp,&
                                                            v( 1_ilp, q ), 1_ilp )
                                               end if
                                            end if
                                         else
                                            if( work( q )>=one ) then
                                               call stdlib_daxpy( m, t*apoaq,a( 1_ilp, p ), 1_ilp,a( 1_ilp, q &
                                                         ), 1_ilp )
                                               call stdlib_daxpy( m, -cs*sn*aqoap,a( 1_ilp, q ), 1_ilp,a( &
                                                         1_ilp, p ), 1_ilp )
                                               work( p ) = work( p ) / cs
                                               work( q ) = work( q )*cs
                                               if( rsvec ) then
                                                  call stdlib_daxpy( mvl, t*apoaq,v( 1_ilp, p ), 1_ilp,v( &
                                                            1_ilp, q ), 1_ilp )
                                                  call stdlib_daxpy( mvl,-cs*sn*aqoap,v( 1_ilp, q ), &
                                                            1_ilp,v( 1_ilp, p ), 1_ilp )
                                               end if
                                            else
                                               if( work( p )>=work( q ) )then
                                                  call stdlib_daxpy( m, -t*aqoap,a( 1_ilp, q ), 1_ilp,a( &
                                                            1_ilp, p ), 1_ilp )
                                                  call stdlib_daxpy( m, cs*sn*apoaq,a( 1_ilp, p ), 1_ilp,&
                                                            a( 1_ilp, q ), 1_ilp )
                                                  work( p ) = work( p )*cs
                                                  work( q ) = work( q ) / cs
                                                  if( rsvec ) then
                                                     call stdlib_daxpy( mvl,-t*aqoap,v( 1_ilp, q ), 1_ilp,&
                                                               v( 1_ilp, p ), 1_ilp )
                                                     call stdlib_daxpy( mvl,cs*sn*apoaq,v( 1_ilp, p ),&
                                                                1_ilp,v( 1_ilp, q ), 1_ilp )
                                                  end if
                                               else
                                                  call stdlib_daxpy( m, t*apoaq,a( 1_ilp, p ), 1_ilp,a( 1_ilp,&
                                                             q ), 1_ilp )
                                                  call stdlib_daxpy( m,-cs*sn*aqoap,a( 1_ilp, q ), 1_ilp,&
                                                            a( 1_ilp, p ), 1_ilp )
                                                  work( p ) = work( p ) / cs
                                                  work( q ) = work( q )*cs
                                                  if( rsvec ) then
                                                     call stdlib_daxpy( mvl,t*apoaq, v( 1_ilp, p ),1_ilp, &
                                                               v( 1_ilp, q ), 1_ilp )
                                                     call stdlib_daxpy( mvl,-cs*sn*aqoap,v( 1_ilp, q )&
                                                               , 1_ilp,v( 1_ilp, p ), 1_ilp )
                                                  end if
                                               end if
                                            end if
                                         end if
                                      end if
                                   else
                    ! .. have to use modified gram-schmidt like transformation
                                      call stdlib_dcopy( m, a( 1_ilp, p ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aapp, one, m,1_ilp, work( n+1 ), &
                                                lda,ierr )
                                      call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aaqq, one, m,1_ilp, a( 1_ilp, q ), &
                                                lda, ierr )
                                      temp1 = -aapq*work( p ) / work( q )
                                      call stdlib_daxpy( m, temp1, work( n+1 ), 1_ilp,a( 1_ilp, q ), 1_ilp )
                                                
                                      call stdlib_dlascl( 'G', 0_ilp, 0_ilp, one, aaqq, m,1_ilp, a( 1_ilp, q ), &
                                                lda, ierr )
                                      sva( q ) = aaqq*sqrt( max( zero,one-aapq*aapq ) )
                                      mxsinj = max( mxsinj, sfmin )
                                   end if
                 ! end if rotok then ... else
                 ! in the case of cancellation in updating sva(q), sva(p)
                 ! recompute sva(q), sva(p).
                                   if( ( sva( q ) / aaqq )**2_ilp<=rooteps )then
                                      if( ( aaqq<rootbig ) .and.( aaqq>rootsfmin ) ) then
                                         sva( q ) = stdlib_dnrm2( m, a( 1_ilp, q ), 1_ilp )*work( q )
                                                   
                                      else
                                         t = zero
                                         aaqq = one
                                         call stdlib_dlassq( m, a( 1_ilp, q ), 1_ilp, t,aaqq )
                                         sva( q ) = t*sqrt( aaqq )*work( q )
                                      end if
                                   end if
                                   if( ( aapp / aapp0 )<=rooteps ) then
                                      if( ( aapp<rootbig ) .and.( aapp>rootsfmin ) ) then
                                         aapp = stdlib_dnrm2( m, a( 1_ilp, p ), 1_ilp )*work( p )
                                      else
                                         t = zero
                                         aapp = one
                                         call stdlib_dlassq( m, a( 1_ilp, p ), 1_ilp, t,aapp )
                                         aapp = t*sqrt( aapp )*work( p )
                                      end if
                                      sva( p ) = aapp
                                   end if
                                else
              ! a(:,p) and a(:,q) already numerically orthogonal
                                   if( ir1==0_ilp )notrot = notrot + 1_ilp
      ! [rtd]      skipped  = skipped  + 1
                                   pskipped = pskipped + 1_ilp
                                end if
                             else
              ! a(:,q) is zero column
                                if( ir1==0_ilp )notrot = notrot + 1_ilp
                                pskipped = pskipped + 1_ilp
                             end if
                             if( ( i<=swband ) .and.( pskipped>rowskip ) ) then
                                if( ir1==0_ilp )aapp = -aapp
                                notrot = 0_ilp
                                go to 2103
                             end if
                          end do loop_2002
           ! end q-loop
           2103 continue
           ! bailed out of q-loop
                          sva( p ) = aapp
                       else
                          sva( p ) = aapp
                          if( ( ir1==0_ilp ) .and. ( aapp==zero ) )notrot = notrot + min( igl+kbl-1, &
                                    n ) - p
                       end if
                    end do loop_2001
           ! end of the p-loop
           ! end of doing the block ( ibr, ibr )
                 end do loop_1002
           ! end of ir1-loop
       ! ... go to the off diagonal blocks
                 igl = ( ibr-1 )*kbl + 1_ilp
                 loop_2010: do jbc = ibr + 1, nbl
                    jgl = ( jbc-1 )*kbl + 1_ilp
              ! doing the block at ( ibr, jbc )
                    ijblsk = 0_ilp
                    loop_2100: do p = igl, min( igl+kbl-1, n )
                       aapp = sva( p )
                       if( aapp>zero ) then
                          pskipped = 0_ilp
                          loop_2200: do q = jgl, min( jgl+kbl-1, n )
                             aaqq = sva( q )
                             if( aaqq>zero ) then
                                aapp0 = aapp
           ! M X 2 Jacobi Svd 
              ! safe gram matrix computation
                                if( aaqq>=one ) then
                                   if( aapp>=aaqq ) then
                                      rotok = ( small*aapp )<=aaqq
                                   else
                                      rotok = ( small*aaqq )<=aapp
                                   end if
                                   if( aapp<( big / aaqq ) ) then
                                      aapq = ( stdlib_ddot( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp,q ), 1_ilp )*work( &
                                                p )*work( q ) /aaqq ) / aapp
                                   else
                                      call stdlib_dcopy( m, a( 1_ilp, p ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aapp,work( p ), m, 1_ilp,work( n+&
                                                1_ilp ), lda, ierr )
                                      aapq = stdlib_ddot( m, work( n+1 ), 1_ilp,a( 1_ilp, q ), 1_ilp )*work( &
                                                q ) / aaqq
                                   end if
                                else
                                   if( aapp>=aaqq ) then
                                      rotok = aapp<=( aaqq / small )
                                   else
                                      rotok = aaqq<=( aapp / small )
                                   end if
                                   if( aapp>( small / aaqq ) ) then
                                      aapq = ( stdlib_ddot( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp,q ), 1_ilp )*work( &
                                                p )*work( q ) /aaqq ) / aapp
                                   else
                                      call stdlib_dcopy( m, a( 1_ilp, q ), 1_ilp,work( n+1 ), 1_ilp )
                                      call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aaqq,work( q ), m, 1_ilp,work( n+&
                                                1_ilp ), lda, ierr )
                                      aapq = stdlib_ddot( m, work( n+1 ), 1_ilp,a( 1_ilp, p ), 1_ilp )*work( &
                                                p ) / aapp
                                   end if
                                end if
                                mxaapq = max( mxaapq, abs( aapq ) )
              ! to rotate or not to rotate, that is the question ...
                                if( abs( aapq )>tol ) then
                                   notrot = 0_ilp
      ! [rtd]      rotated  = rotated + 1
                                   pskipped = 0_ilp
                                   iswrot = iswrot + 1_ilp
                                   if( rotok ) then
                                      aqoap = aaqq / aapp
                                      apoaq = aapp / aaqq
                                      theta = -half*abs(aqoap-apoaq)/aapq
                                      if( aaqq>aapp0 )theta = -theta
                                      if( abs( theta )>bigtheta ) then
                                         t = half / theta
                                         fastr( 3_ilp ) = t*work( p ) / work( q )
                                         fastr( 4_ilp ) = -t*work( q ) /work( p )
                                         call stdlib_drotm( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp, fastr )
                                                   
                                         if( rsvec )call stdlib_drotm( mvl,v( 1_ilp, p ), 1_ilp,v( 1_ilp, q ),&
                                                    1_ilp,fastr )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq ) )
                                         mxsinj = max( mxsinj, abs( t ) )
                                      else
                       ! Choose Correct Signum For Theta And Rotate
                                         thsign = -sign( one, aapq )
                                         if( aaqq>aapp0 )thsign = -thsign
                                         t = one / ( theta+thsign*sqrt( one+theta*theta ) )
                                                   
                                         cs = sqrt( one / ( one+t*t ) )
                                         sn = t*cs
                                         mxsinj = max( mxsinj, abs( sn ) )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq ) )
                                         apoaq = work( p ) / work( q )
                                         aqoap = work( q ) / work( p )
                                         if( work( p )>=one ) then
                                            if( work( q )>=one ) then
                                               fastr( 3_ilp ) = t*apoaq
                                               fastr( 4_ilp ) = -t*aqoap
                                               work( p ) = work( p )*cs
                                               work( q ) = work( q )*cs
                                               call stdlib_drotm( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp,&
                                                         fastr )
                                               if( rsvec )call stdlib_drotm( mvl,v( 1_ilp, p ), 1_ilp, v( &
                                                         1_ilp, q ),1_ilp, fastr )
                                            else
                                               call stdlib_daxpy( m, -t*aqoap,a( 1_ilp, q ), 1_ilp,a( 1_ilp, &
                                                         p ), 1_ilp )
                                               call stdlib_daxpy( m, cs*sn*apoaq,a( 1_ilp, p ), 1_ilp,a( &
                                                         1_ilp, q ), 1_ilp )
                                               if( rsvec ) then
                                                  call stdlib_daxpy( mvl, -t*aqoap,v( 1_ilp, q ), 1_ilp,v(&
                                                             1_ilp, p ), 1_ilp )
                                                  call stdlib_daxpy( mvl,cs*sn*apoaq,v( 1_ilp, p ), 1_ilp,&
                                                            v( 1_ilp, q ), 1_ilp )
                                               end if
                                               work( p ) = work( p )*cs
                                               work( q ) = work( q ) / cs
                                            end if
                                         else
                                            if( work( q )>=one ) then
                                               call stdlib_daxpy( m, t*apoaq,a( 1_ilp, p ), 1_ilp,a( 1_ilp, q &
                                                         ), 1_ilp )
                                               call stdlib_daxpy( m, -cs*sn*aqoap,a( 1_ilp, q ), 1_ilp,a( &
                                                         1_ilp, p ), 1_ilp )
                                               if( rsvec ) then
                                                  call stdlib_daxpy( mvl, t*apoaq,v( 1_ilp, p ), 1_ilp,v( &
                                                            1_ilp, q ), 1_ilp )
                                                  call stdlib_daxpy( mvl,-cs*sn*aqoap,v( 1_ilp, q ), &
                                                            1_ilp,v( 1_ilp, p ), 1_ilp )
                                               end if
                                               work( p ) = work( p ) / cs
                                               work( q ) = work( q )*cs
                                            else
                                               if( work( p )>=work( q ) )then
                                                  call stdlib_daxpy( m, -t*aqoap,a( 1_ilp, q ), 1_ilp,a( &
                                                            1_ilp, p ), 1_ilp )
                                                  call stdlib_daxpy( m, cs*sn*apoaq,a( 1_ilp, p ), 1_ilp,&
                                                            a( 1_ilp, q ), 1_ilp )
                                                  work( p ) = work( p )*cs
                                                  work( q ) = work( q ) / cs
                                                  if( rsvec ) then
                                                     call stdlib_daxpy( mvl,-t*aqoap,v( 1_ilp, q ), 1_ilp,&
                                                               v( 1_ilp, p ), 1_ilp )
                                                     call stdlib_daxpy( mvl,cs*sn*apoaq,v( 1_ilp, p ),&
                                                                1_ilp,v( 1_ilp, q ), 1_ilp )
                                                  end if
                                               else
                                                  call stdlib_daxpy( m, t*apoaq,a( 1_ilp, p ), 1_ilp,a( 1_ilp,&
                                                             q ), 1_ilp )
                                                  call stdlib_daxpy( m,-cs*sn*aqoap,a( 1_ilp, q ), 1_ilp,&
                                                            a( 1_ilp, p ), 1_ilp )
                                                  work( p ) = work( p ) / cs
                                                  work( q ) = work( q )*cs
                                                  if( rsvec ) then
                                                     call stdlib_daxpy( mvl,t*apoaq, v( 1_ilp, p ),1_ilp, &
                                                               v( 1_ilp, q ), 1_ilp )
                                                     call stdlib_daxpy( mvl,-cs*sn*aqoap,v( 1_ilp, q )&
                                                               , 1_ilp,v( 1_ilp, p ), 1_ilp )
                                                  end if
                                               end if
                                            end if
                                         end if
                                      end if
                                   else
                                      if( aapp>aaqq ) then
                                         call stdlib_dcopy( m, a( 1_ilp, p ), 1_ilp,work( n+1 ), 1_ilp )
                                                   
                                         call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, work( n+1 &
                                                   ), lda,ierr )
                                         call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aaqq, one,m, 1_ilp, a( 1_ilp, q ),&
                                                    lda,ierr )
                                         temp1 = -aapq*work( p ) / work( q )
                                         call stdlib_daxpy( m, temp1, work( n+1 ),1_ilp, a( 1_ilp, q ), 1_ilp &
                                                   )
                                         call stdlib_dlascl( 'G', 0_ilp, 0_ilp, one, aaqq,m, 1_ilp, a( 1_ilp, q ),&
                                                    lda,ierr )
                                         sva( q ) = aaqq*sqrt( max( zero,one-aapq*aapq ) )
                                         mxsinj = max( mxsinj, sfmin )
                                      else
                                         call stdlib_dcopy( m, a( 1_ilp, q ), 1_ilp,work( n+1 ), 1_ilp )
                                                   
                                         call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aaqq, one,m, 1_ilp, work( n+1 &
                                                   ), lda,ierr )
                                         call stdlib_dlascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, a( 1_ilp, p ),&
                                                    lda,ierr )
                                         temp1 = -aapq*work( q ) / work( p )
                                         call stdlib_daxpy( m, temp1, work( n+1 ),1_ilp, a( 1_ilp, p ), 1_ilp &
                                                   )
                                         call stdlib_dlascl( 'G', 0_ilp, 0_ilp, one, aapp,m, 1_ilp, a( 1_ilp, p ),&
                                                    lda,ierr )
                                         sva( p ) = aapp*sqrt( max( zero,one-aapq*aapq ) )
                                         mxsinj = max( mxsinj, sfmin )
                                      end if
                                   end if
                 ! end if rotok then ... else
                 ! in the case of cancellation in updating sva(q)
                 ! .. recompute sva(q)
                                   if( ( sva( q ) / aaqq )**2_ilp<=rooteps )then
                                      if( ( aaqq<rootbig ) .and.( aaqq>rootsfmin ) ) then
                                         sva( q ) = stdlib_dnrm2( m, a( 1_ilp, q ), 1_ilp )*work( q )
                                                   
                                      else
                                         t = zero
                                         aaqq = one
                                         call stdlib_dlassq( m, a( 1_ilp, q ), 1_ilp, t,aaqq )
                                         sva( q ) = t*sqrt( aaqq )*work( q )
                                      end if
                                   end if
                                   if( ( aapp / aapp0 )**2_ilp<=rooteps ) then
                                      if( ( aapp<rootbig ) .and.( aapp>rootsfmin ) ) then
                                         aapp = stdlib_dnrm2( m, a( 1_ilp, p ), 1_ilp )*work( p )
                                      else
                                         t = zero
                                         aapp = one
                                         call stdlib_dlassq( m, a( 1_ilp, p ), 1_ilp, t,aapp )
                                         aapp = t*sqrt( aapp )*work( p )
                                      end if
                                      sva( p ) = aapp
                                   end if
                    ! end of ok rotation
                                else
                                   notrot = notrot + 1_ilp
      ! [rtd]      skipped  = skipped  + 1
                                   pskipped = pskipped + 1_ilp
                                   ijblsk = ijblsk + 1_ilp
                                end if
                             else
                                notrot = notrot + 1_ilp
                                pskipped = pskipped + 1_ilp
                                ijblsk = ijblsk + 1_ilp
                             end if
                             if( ( i<=swband ) .and. ( ijblsk>=blskip ) )then
                                sva( p ) = aapp
                                notrot = 0_ilp
                                go to 2011
                             end if
                             if( ( i<=swband ) .and.( pskipped>rowskip ) ) then
                                aapp = -aapp
                                notrot = 0_ilp
                                go to 2203
                             end if
                          end do loop_2200
              ! end of the q-loop
              2203 continue
                          sva( p ) = aapp
                       else
                          if( aapp==zero )notrot = notrot +min( jgl+kbl-1, n ) - jgl + 1_ilp
                          if( aapp<zero )notrot = 0_ilp
                       end if
                    end do loop_2100
           ! end of the p-loop
                 end do loop_2010
           ! end of the jbc-loop
           2011 continue
      ! 2011 bailed out of the jbc-loop
                 do p = igl, min( igl+kbl-1, n )
                    sva( p ) = abs( sva( p ) )
                 end do
      ! **
              end do loop_2000
      ! 2000 :: end of the ibr-loop
           ! .. update sva(n)
              if( ( sva( n )<rootbig ) .and. ( sva( n )>rootsfmin ) )then
                 sva( n ) = stdlib_dnrm2( m, a( 1_ilp, n ), 1_ilp )*work( n )
              else
                 t = zero
                 aapp = one
                 call stdlib_dlassq( m, a( 1_ilp, n ), 1_ilp, t, aapp )
                 sva( n ) = t*sqrt( aapp )*work( n )
              end if
           ! additional steering devices
              if( ( i<swband ) .and. ( ( mxaapq<=roottol ) .or.( iswrot<=n ) ) )swband = i
              if( ( i>swband+1 ) .and. ( mxaapq<sqrt( real( n,KIND=dp) )*tol ) .and. ( real( n,&
                        KIND=dp)*mxaapq*mxsinj<tol ) ) then
                 go to 1994
              end if
              if( notrot>=emptsw )go to 1994
           end do loop_1993
           ! end i=1:nsweep loop
       ! #:( reaching this point means that the procedure has not converged.
           info = nsweep - 1_ilp
           go to 1995
           1994 continue
       ! #:) reaching this point means numerical convergence after the i-th
           ! sweep.
           info = 0_ilp
       ! #:) info = 0 confirms successful iterations.
       1995 continue
           ! sort the singular values and find how many are above
           ! the underflow threshold.
           n2 = 0_ilp
           n4 = 0_ilp
           do p = 1, n - 1
              q = stdlib_idamax( n-p+1, sva( p ), 1_ilp ) + p - 1_ilp
              if( p/=q ) then
                 temp1 = sva( p )
                 sva( p ) = sva( q )
                 sva( q ) = temp1
                 temp1 = work( p )
                 work( p ) = work( q )
                 work( q ) = temp1
                 call stdlib_dswap( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp, q ), 1_ilp )
                 if( rsvec )call stdlib_dswap( mvl, v( 1_ilp, p ), 1_ilp, v( 1_ilp, q ), 1_ilp )
              end if
              if( sva( p )/=zero ) then
                 n4 = n4 + 1_ilp
                 if( sva( p )*skl>sfmin )n2 = n2 + 1_ilp
              end if
           end do
           if( sva( n )/=zero ) then
              n4 = n4 + 1_ilp
              if( sva( n )*skl>sfmin )n2 = n2 + 1_ilp
           end if
           ! normalize the left singular vectors.
           if( lsvec .or. uctol ) then
              do p = 1, n2
                 call stdlib_dscal( m, work( p ) / sva( p ), a( 1_ilp, p ), 1_ilp )
              end do
           end if
           ! scale the product of jacobi rotations (assemble the fast rotations).
           if( rsvec ) then
              if( applv ) then
                 do p = 1, n
                    call stdlib_dscal( mvl, work( p ), v( 1_ilp, p ), 1_ilp )
                 end do
              else
                 do p = 1, n
                    temp1 = one / stdlib_dnrm2( mvl, v( 1_ilp, p ), 1_ilp )
                    call stdlib_dscal( mvl, temp1, v( 1_ilp, p ), 1_ilp )
                 end do
              end if
           end if
           ! undo scaling, if necessary (and possible).
           if( ( ( skl>one ) .and. ( sva( 1_ilp )<( big / skl) ) ).or. ( ( skl<one ) .and. ( sva( max(&
                      n2, 1_ilp ) ) >( sfmin / skl) ) ) ) then
              do p = 1, n
                 sva( p ) = skl*sva( p )
              end do
              skl= one
           end if
           work( 1_ilp ) = skl
           ! the singular values of a are skl*sva(1:n). if skl/=one
           ! then some of the singular values may overflow or underflow and
           ! the spectrum is given in this factored representation.
           work( 2_ilp ) = real( n4,KIND=dp)
           ! n4 is the number of computed nonzero singular values of a.
           work( 3_ilp ) = real( n2,KIND=dp)
           ! n2 is the number of singular values of a greater than sfmin.
           ! if n2<n, sva(n2:n) contains zeros and/or denormalized numbers
           ! that may carry some information.
           work( 4_ilp ) = real( i,KIND=dp)
           ! i is the index of the last sweep before declaring convergence.
           work( 5_ilp ) = mxaapq
           ! mxaapq is the largest absolute value of scaled pivots in the
           ! last sweep
           work( 6_ilp ) = mxsinj
           ! mxsinj is the largest absolute value of the sines of jacobi angles
           ! in the last sweep
           return
     end subroutine stdlib_dgesvj


     pure module subroutine stdlib_cgesvj( joba, jobu, jobv, m, n, a, lda, sva, mv, v,ldv, cwork, lwork, &
     !! CGESVJ computes the singular value decomposition (SVD) of a complex
     !! M-by-N matrix A, where M >= N. The SVD of A is written as
     !! [++]   [xx]   [x0]   [xx]
     !! A = U * SIGMA * V^*,  [++] = [xx] * [ox] * [xx]
     !! [++]   [xx]
     !! where SIGMA is an N-by-N diagonal matrix, U is an M-by-N orthonormal
     !! matrix, and V is an N-by-N unitary matrix. The diagonal elements
     !! of SIGMA are the singular values of A. The columns of U and V are the
     !! left and the right singular vectors of A, respectively.
               rwork, lrwork, info )
        ! -- lapack computational routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_sp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldv, lwork, lrwork, m, mv, n
           character, intent(in) :: joba, jobu, jobv
           ! Array Arguments 
           complex(sp), intent(inout) :: a(lda,*), v(ldv,*), cwork(lwork)
           real(sp), intent(inout) :: rwork(lrwork)
           real(sp), intent(out) :: sva(n)
        ! =====================================================================
           ! Local Parameters 
           integer(ilp), parameter :: nsweep = 30_ilp
           
           
           
           ! Local Scalars 
           complex(sp) :: aapq, ompq
           real(sp) :: aapp, aapp0, aapq1, aaqq, apoaq, aqoap, big, bigtheta, cs, ctol, epsln, &
           mxaapq, mxsinj, rootbig, rooteps, rootsfmin, roottol, skl, sfmin, small, sn, t, temp1, &
                     theta, thsign, tol
           integer(ilp) :: blskip, emptsw, i, ibr, ierr, igl, ijblsk, ir1, iswrot, jbc, jgl, kbl, &
                     lkahead, mvl, n2, n34, n4, nbl, notrot, p, pskipped, q, rowskip, swband
           logical(lk) :: applv, goscale, lower, lquery, lsvec, noscale, rotok, rsvec, uctol, &
                     upper
           ! Intrinsic Functions 
           ! from lapack
           ! from lapack
           ! Executable Statements 
           ! test the input arguments
           lsvec = stdlib_lsame( jobu, 'U' ) .or. stdlib_lsame( jobu, 'F' )
           uctol = stdlib_lsame( jobu, 'C' )
           rsvec = stdlib_lsame( jobv, 'V' ) .or. stdlib_lsame( jobv, 'J' )
           applv = stdlib_lsame( jobv, 'A' )
           upper = stdlib_lsame( joba, 'U' )
           lower = stdlib_lsame( joba, 'L' )
           lquery = ( lwork == -1_ilp ) .or. ( lrwork == -1_ilp )
           if( .not.( upper .or. lower .or. stdlib_lsame( joba, 'G' ) ) ) then
              info = -1_ilp
           else if( .not.( lsvec .or. uctol .or. stdlib_lsame( jobu, 'N' ) ) ) then
              info = -2_ilp
           else if( .not.( rsvec .or. applv .or. stdlib_lsame( jobv, 'N' ) ) ) then
              info = -3_ilp
           else if( m<0_ilp ) then
              info = -4_ilp
           else if( ( n<0_ilp ) .or. ( n>m ) ) then
              info = -5_ilp
           else if( lda<m ) then
              info = -7_ilp
           else if( mv<0_ilp ) then
              info = -9_ilp
           else if( ( rsvec .and. ( ldv<n ) ) .or.( applv .and. ( ldv<mv ) ) ) then
              info = -11_ilp
           else if( uctol .and. ( rwork( 1_ilp )<=one ) ) then
              info = -12_ilp
           else if( lwork<( m+n ) .and. ( .not.lquery ) ) then
              info = -13_ilp
           else if( lrwork<max( n, 6_ilp ) .and. ( .not.lquery ) ) then
              info = -15_ilp
           else
              info = 0_ilp
           end if
           ! #:(
           if( info/=0_ilp ) then
              call stdlib_xerbla( 'CGESVJ', -info )
              return
           else if ( lquery ) then
              cwork(1_ilp) = m + n
              rwork(1_ilp) = max( n, 6_ilp )
              return
           end if
       ! #:) quick return for void matrix
           if( ( m==0 ) .or. ( n==0 ) )return
           ! set numerical parameters
           ! the stopping criterion for jacobi rotations is
           ! max_{i<>j}|a(:,i)^* * a(:,j)| / (||a(:,i)||*||a(:,j)||) < ctol*eps
           ! where eps is the round-off and ctol is defined as follows:
           if( uctol ) then
              ! ... user controlled
              ctol = rwork( 1_ilp )
           else
              ! ... default
              if( lsvec .or. rsvec .or. applv ) then
                 ctol = sqrt( real( m,KIND=sp) )
              else
                 ctol = real( m,KIND=sp)
              end if
           end if
           ! ... and the machine dependent parameters are
      ! [!]  (make sure that stdlib_slamch() works properly on the target machine.)
           epsln = stdlib_slamch( 'EPSILON' )
           rooteps = sqrt( epsln )
           sfmin = stdlib_slamch( 'SAFEMINIMUM' )
           rootsfmin = sqrt( sfmin )
           small = sfmin / epsln
            ! big = stdlib_slamch( 'overflow' )
           big     = one  / sfmin
           rootbig = one / rootsfmin
           ! large = big / sqrt( real( m*n,KIND=sp) )
           bigtheta = one / rooteps
           tol = ctol*epsln
           roottol = sqrt( tol )
           if( real( m,KIND=sp)*epsln>=one ) then
              info = -4_ilp
              call stdlib_xerbla( 'CGESVJ', -info )
              return
           end if
           ! initialize the right singular vector matrix.
           if( rsvec ) then
              mvl = n
              call stdlib_claset( 'A', mvl, n, czero, cone, v, ldv )
           else if( applv ) then
              mvl = mv
           end if
           rsvec = rsvec .or. applv
           ! initialize sva( 1:n ) = ( ||a e_i||_2, i = 1:n )
      ! (!)  if necessary, scale a to protect the largest singular value
           ! from overflow. it is possible that saving the largest singular
           ! value destroys the information about the small ones.
           ! this initial scaling is almost minimal in the sense that the
           ! goal is to make sure that no column norm overflows, and that
           ! sqrt(n)*max_i sva(i) does not overflow. if infinite entries
           ! in a are detected, the procedure returns with info=-6.
           skl = one / sqrt( real( m,KIND=sp)*real( n,KIND=sp) )
           noscale = .true.
           goscale = .true.
           if( lower ) then
              ! the input matrix is m-by-n lower triangular (trapezoidal)
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_classq( m-p+1, a( p, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'CGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           else if( upper ) then
              ! the input matrix is m-by-n upper triangular (trapezoidal)
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_classq( p, a( 1_ilp, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'CGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           else
              ! the input matrix is m-by-n general dense
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_classq( m, a( 1_ilp, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'CGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           end if
           if( noscale )skl = one
           ! move the smaller part of the spectrum from the underflow threshold
      ! (!)  start by determining the position of the nonzero entries of the
           ! array sva() relative to ( sfmin, big ).
           aapp = zero
           aaqq = big
           do p = 1, n
              if( sva( p )/=zero )aaqq = min( aaqq, sva( p ) )
              aapp = max( aapp, sva( p ) )
           end do
       ! #:) quick return for zero matrix
           if( aapp==zero ) then
              if( lsvec )call stdlib_claset( 'G', m, n, czero, cone, a, lda )
              rwork( 1_ilp ) = one
              rwork( 2_ilp ) = zero
              rwork( 3_ilp ) = zero
              rwork( 4_ilp ) = zero
              rwork( 5_ilp ) = zero
              rwork( 6_ilp ) = zero
              return
           end if
       ! #:) quick return for one-column matrix
           if( n==1_ilp ) then
              if( lsvec )call stdlib_clascl( 'G', 0_ilp, 0_ilp, sva( 1_ilp ), skl, m, 1_ilp,a( 1_ilp, 1_ilp ), lda, ierr )
                        
              rwork( 1_ilp ) = one / skl
              if( sva( 1_ilp )>=sfmin ) then
                 rwork( 2_ilp ) = one
              else
                 rwork( 2_ilp ) = zero
              end if
              rwork( 3_ilp ) = zero
              rwork( 4_ilp ) = zero
              rwork( 5_ilp ) = zero
              rwork( 6_ilp ) = zero
              return
           end if
           ! protect small singular values from underflow, and try to
           ! avoid underflows/overflows in computing jacobi rotations.
           sn = sqrt( sfmin / epsln )
           temp1 = sqrt( big / real( n,KIND=sp) )
           if( ( aapp<=sn ) .or. ( aaqq>=temp1 ) .or.( ( sn<=aaqq ) .and. ( aapp<=temp1 ) ) ) &
                     then
              temp1 = min( big, temp1 / aapp )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq<=sn ) .and. ( aapp<=temp1 ) ) then
              temp1 = min( sn / aaqq, big / ( aapp*sqrt( real( n,KIND=sp) ) ) )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq>=sn ) .and. ( aapp>=temp1 ) ) then
              temp1 = max( sn / aaqq, temp1 / aapp )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq<=sn ) .and. ( aapp>=temp1 ) ) then
              temp1 = min( sn / aaqq, big / ( sqrt( real( n,KIND=sp) )*aapp ) )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else
              temp1 = one
           end if
           ! scale, if necessary
           if( temp1/=one ) then
              call stdlib_slascl( 'G', 0_ilp, 0_ilp, one, temp1, n, 1_ilp, sva, n, ierr )
           end if
           skl = temp1*skl
           if( skl/=one ) then
              call stdlib_clascl( joba, 0_ilp, 0_ilp, one, skl, m, n, a, lda, ierr )
              skl = one / skl
           end if
           ! row-cyclic jacobi svd algorithm with column pivoting
           emptsw = ( n*( n-1 ) ) / 2_ilp
           notrot = 0_ilp
           do q = 1, n
              cwork( q ) = cone
           end do
           swband = 3_ilp
      ! [tp] swband is a tuning parameter [tp]. it is meaningful and effective
           ! if stdlib_cgesvj is used as a computational routine in the preconditioned
           ! jacobi svd algorithm stdlib_cgejsv. for sweeps i=1:swband the procedure
           ! works on pivots inside a band-like region around the diagonal.
           ! the boundaries are determined dynamically, based on the number of
           ! pivots above a threshold.
           kbl = min( 8_ilp, n )
      ! [tp] kbl is a tuning parameter that defines the tile size in the
           ! tiling of the p-q loops of pivot pairs. in general, an optimal
           ! value of kbl depends on the matrix dimensions and on the
           ! parameters of the computer's memory.
           nbl = n / kbl
           if( ( nbl*kbl )/=n )nbl = nbl + 1_ilp
           blskip = kbl**2_ilp
      ! [tp] blkskip is a tuning parameter that depends on swband and kbl.
           rowskip = min( 5_ilp, kbl )
      ! [tp] rowskip is a tuning parameter.
           lkahead = 1_ilp
      ! [tp] lkahead is a tuning parameter.
           ! quasi block transformations, using the lower (upper) triangular
           ! structure of the input matrix. the quasi-block-cycling usually
           ! invokes cubic convergence. big part of this cycle is done inside
           ! canonical subspaces of dimensions less than m.
           if( ( lower .or. upper ) .and. ( n>max( 64_ilp, 4_ilp*kbl ) ) ) then
      ! [tp] the number of partition levels and the actual partition are
           ! tuning parameters.
              n4 = n / 4_ilp
              n2 = n / 2_ilp
              n34 = 3_ilp*n4
              if( applv ) then
                 q = 0_ilp
              else
                 q = 1_ilp
              end if
              if( lower ) then
           ! this works very well on lower triangular matrices, in particular
           ! in the framework of the preconditioned jacobi svd (xgejsv).
           ! the idea is simple:
           ! [+ 0 0 0]   note that jacobi transformations of [0 0]
           ! [+ + 0 0]                                       [0 0]
           ! [+ + x 0]   actually work on [x 0]              [x 0]
           ! [+ + x x]                    [x x].             [x x]
                 call stdlib_cgsvj0( jobv, m-n34, n-n34, a( n34+1, n34+1 ), lda,cwork( n34+1 ), &
                 sva( n34+1 ), mvl,v( n34*q+1, n34+1 ), ldv, epsln, sfmin, tol,2_ilp, cwork( n+1 ), &
                           lwork-n, ierr )
                 call stdlib_cgsvj0( jobv, m-n2, n34-n2, a( n2+1, n2+1 ), lda,cwork( n2+1 ), sva( &
                 n2+1 ), mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 2_ilp,cwork( n+1 ), lwork-n, &
                           ierr )
                 call stdlib_cgsvj1( jobv, m-n2, n-n2, n4, a( n2+1, n2+1 ), lda,cwork( n2+1 ), &
                 sva( n2+1 ), mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 1_ilp,cwork( n+1 ), &
                           lwork-n, ierr )
                 call stdlib_cgsvj0( jobv, m-n4, n2-n4, a( n4+1, n4+1 ), lda,cwork( n4+1 ), sva( &
                 n4+1 ), mvl,v( n4*q+1, n4+1 ), ldv, epsln, sfmin, tol, 1_ilp,cwork( n+1 ), lwork-n, &
                           ierr )
                 call stdlib_cgsvj0( jobv, m, n4, a, lda, cwork, sva, mvl, v, ldv,epsln, sfmin, &
                           tol, 1_ilp, cwork( n+1 ), lwork-n,ierr )
                 call stdlib_cgsvj1( jobv, m, n2, n4, a, lda, cwork, sva, mvl, v,ldv, epsln, &
                           sfmin, tol, 1_ilp, cwork( n+1 ),lwork-n, ierr )
              else if( upper ) then
                 call stdlib_cgsvj0( jobv, n4, n4, a, lda, cwork, sva, mvl, v, ldv,epsln, sfmin, &
                           tol, 2_ilp, cwork( n+1 ), lwork-n,ierr )
                 call stdlib_cgsvj0( jobv, n2, n4, a( 1_ilp, n4+1 ), lda, cwork( n4+1 ),sva( n4+1 ), &
                 mvl, v( n4*q+1, n4+1 ), ldv,epsln, sfmin, tol, 1_ilp, cwork( n+1 ), lwork-n,ierr )
                           
                 call stdlib_cgsvj1( jobv, n2, n2, n4, a, lda, cwork, sva, mvl, v,ldv, epsln, &
                           sfmin, tol, 1_ilp, cwork( n+1 ),lwork-n, ierr )
                 call stdlib_cgsvj0( jobv, n2+n4, n4, a( 1_ilp, n2+1 ), lda,cwork( n2+1 ), sva( n2+1 )&
                 , mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 1_ilp,cwork( n+1 ), lwork-n, ierr )
                           
              end if
           end if
           ! .. row-cyclic pivot strategy with de rijk's pivoting ..
           loop_1993: do i = 1, nsweep
           ! .. go go go ...
              mxaapq = zero
              mxsinj = zero
              iswrot = 0_ilp
              notrot = 0_ilp
              pskipped = 0_ilp
           ! each sweep is unrolled using kbl-by-kbl tiles over the pivot pairs
           ! 1 <= p < q <= n. this is the first step toward a blocked implementation
           ! of the rotations. new implementation, based on block transformations,
           ! is under development.
              loop_2000: do ibr = 1, nbl
                 igl = ( ibr-1 )*kbl + 1_ilp
                 loop_1002: do ir1 = 0, min( lkahead, nbl-ibr )
                    igl = igl + ir1*kbl
                    loop_2001: do p = igl, min( igl+kbl-1, n-1 )
           ! .. de rijk's pivoting
                       q = stdlib_isamax( n-p+1, sva( p ), 1_ilp ) + p - 1_ilp
                       if( p/=q ) then
                          call stdlib_cswap( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp, q ), 1_ilp )
                          if( rsvec )call stdlib_cswap( mvl, v( 1_ilp, p ), 1_ilp,v( 1_ilp, q ), 1_ilp )
                          temp1 = sva( p )
                          sva( p ) = sva( q )
                          sva( q ) = temp1
                          aapq = cwork(p)
                          cwork(p) = cwork(q)
                          cwork(q) = aapq
                       end if
                       if( ir1==0_ilp ) then
              ! column norms are periodically updated by explicit
              ! norm computation.
      ! [!]     caveat:
              ! unfortunately, some blas implementations compute stdlib_scnrm2(m,a(1,p),1)
              ! as sqrt(s=stdlib_cdotc(m,a(1,p),1,a(1,p),1)), which may cause the result to
              ! overflow for ||a(:,p)||_2 > sqrt(overflow_threshold), and to
              ! underflow for ||a(:,p)||_2 < sqrt(underflow_threshold).
              ! hence, stdlib_scnrm2 cannot be trusted, not even in the case when
              ! the true norm is far from the under(over)flow boundaries.
              ! if properly implemented stdlib_scnrm2 is available, the if-then-else-end if
              ! below should be replaced with "aapp = stdlib_scnrm2( m, a(1,p), 1 )".
                          if( ( sva( p )<rootbig ) .and.( sva( p )>rootsfmin ) ) then
                             sva( p ) = stdlib_scnrm2( m, a( 1_ilp, p ), 1_ilp )
                          else
                             temp1 = zero
                             aapp = one
                             call stdlib_classq( m, a( 1_ilp, p ), 1_ilp, temp1, aapp )
                             sva( p ) = temp1*sqrt( aapp )
                          end if
                          aapp = sva( p )
                       else
                          aapp = sva( p )
                       end if
                       if( aapp>zero ) then
                          pskipped = 0_ilp
                          loop_2002: do q = p + 1, min( igl+kbl-1, n )
                             aaqq = sva( q )
                             if( aaqq>zero ) then
                                aapp0 = aapp
                                if( aaqq>=one ) then
                                   rotok = ( small*aapp )<=aaqq
                                   if( aapp<( big / aaqq ) ) then
                                      aapq = ( stdlib_cdotc( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aaqq ) / aapp
                                   else
                                      call stdlib_ccopy( m, a( 1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_clascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, cwork(n+1), &
                                                lda, ierr )
                                      aapq = stdlib_cdotc( m, cwork(n+1), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aaqq
                                   end if
                                else
                                   rotok = aapp<=( aaqq / small )
                                   if( aapp>( small / aaqq ) ) then
                                      aapq = ( stdlib_cdotc( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aapp ) / aaqq
                                   else
                                      call stdlib_ccopy( m, a( 1_ilp, q ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_clascl( 'G', 0_ilp, 0_ilp, aaqq,one, m, 1_ilp,cwork(n+1), &
                                                lda, ierr )
                                      aapq = stdlib_cdotc( m, a(1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp ) / &
                                                aapp
                                   end if
                                end if
                                 ! aapq = aapq * conjg( cwork(p) ) * cwork(q)
                                aapq1  = -abs(aapq)
                                mxaapq = max( mxaapq, -aapq1 )
              ! to rotate or not to rotate, that is the question ...
                                if( abs( aapq1 )>tol ) then
                                    ompq = aapq / abs(aapq)
                 ! Rotate
      ! [rtd]      rotated = rotated + one
                                   if( ir1==0_ilp ) then
                                      notrot = 0_ilp
                                      pskipped = 0_ilp
                                      iswrot = iswrot + 1_ilp
                                   end if
                                   if( rotok ) then
                                      aqoap = aaqq / aapp
                                      apoaq = aapp / aaqq
                                      theta = -half*abs( aqoap-apoaq )/aapq1
                                      if( abs( theta )>bigtheta ) then
                                         t  = half / theta
                                         cs = one
                                         call stdlib_crot( m, a(1_ilp,p), 1_ilp, a(1_ilp,q), 1_ilp,cs, conjg(ompq)&
                                                   *t )
                                         if ( rsvec ) then
                                             call stdlib_crot( mvl, v(1_ilp,p), 1_ilp,v(1_ilp,q), 1_ilp, cs, &
                                                       conjg(ompq)*t )
                                         end if
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq1 ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq1 ) )
                                         mxsinj = max( mxsinj, abs( t ) )
                                      else
                       ! Choose Correct Signum For Theta And Rotate
                                         thsign = -sign( one, aapq1 )
                                         t = one / ( theta+thsign*sqrt( one+theta*theta ) )
                                                   
                                         cs = sqrt( one / ( one+t*t ) )
                                         sn = t*cs
                                         mxsinj = max( mxsinj, abs( sn ) )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq1 ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq1 ) )
                                         call stdlib_crot( m, a(1_ilp,p), 1_ilp, a(1_ilp,q), 1_ilp,cs, conjg(ompq)&
                                                   *sn )
                                         if ( rsvec ) then
                                             call stdlib_crot( mvl, v(1_ilp,p), 1_ilp,v(1_ilp,q), 1_ilp, cs, &
                                                       conjg(ompq)*sn )
                                         end if
                                      end if
                                      cwork(p) = -cwork(q) * ompq
                                      else
                    ! .. have to use modified gram-schmidt like transformation
                                      call stdlib_ccopy( m, a( 1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_clascl( 'G', 0_ilp, 0_ilp, aapp, one, m,1_ilp, cwork(n+1), &
                                                lda,ierr )
                                      call stdlib_clascl( 'G', 0_ilp, 0_ilp, aaqq, one, m,1_ilp, a( 1_ilp, q ), &
                                                lda, ierr )
                                      call stdlib_caxpy( m, -aapq, cwork(n+1), 1_ilp,a( 1_ilp, q ), 1_ilp )
                                                
                                      call stdlib_clascl( 'G', 0_ilp, 0_ilp, one, aaqq, m,1_ilp, a( 1_ilp, q ), &
                                                lda, ierr )
                                      sva( q ) = aaqq*sqrt( max( zero,one-aapq1*aapq1 ) )
                                      mxsinj = max( mxsinj, sfmin )
                                   end if
                 ! end if rotok then ... else
                 ! in the case of cancellation in updating sva(q), sva(p)
                 ! recompute sva(q), sva(p).
                                   if( ( sva( q ) / aaqq )**2_ilp<=rooteps )then
                                      if( ( aaqq<rootbig ) .and.( aaqq>rootsfmin ) ) then
                                         sva( q ) = stdlib_scnrm2( m, a( 1_ilp, q ), 1_ilp )
                                      else
                                         t = zero
                                         aaqq = one
                                         call stdlib_classq( m, a( 1_ilp, q ), 1_ilp, t,aaqq )
                                         sva( q ) = t*sqrt( aaqq )
                                      end if
                                   end if
                                   if( ( aapp / aapp0 )<=rooteps ) then
                                      if( ( aapp<rootbig ) .and.( aapp>rootsfmin ) ) then
                                         aapp = stdlib_scnrm2( m, a( 1_ilp, p ), 1_ilp )
                                      else
                                         t = zero
                                         aapp = one
                                         call stdlib_classq( m, a( 1_ilp, p ), 1_ilp, t,aapp )
                                         aapp = t*sqrt( aapp )
                                      end if
                                      sva( p ) = aapp
                                   end if
                                else
                                   ! a(:,p) and a(:,q) already numerically orthogonal
                                   if( ir1==0_ilp )notrot = notrot + 1_ilp
      ! [rtd]      skipped  = skipped + 1
                                   pskipped = pskipped + 1_ilp
                                end if
                             else
                                ! a(:,q) is zero column
                                if( ir1==0_ilp )notrot = notrot + 1_ilp
                                pskipped = pskipped + 1_ilp
                             end if
                             if( ( i<=swband ) .and.( pskipped>rowskip ) ) then
                                if( ir1==0_ilp )aapp = -aapp
                                notrot = 0_ilp
                                go to 2103
                             end if
                          end do loop_2002
           ! end q-loop
           2103 continue
           ! bailed out of q-loop
                          sva( p ) = aapp
                       else
                          sva( p ) = aapp
                          if( ( ir1==0_ilp ) .and. ( aapp==zero ) )notrot = notrot + min( igl+kbl-1, &
                                    n ) - p
                       end if
                    end do loop_2001
           ! end of the p-loop
           ! end of doing the block ( ibr, ibr )
                 end do loop_1002
           ! end of ir1-loop
       ! ... go to the off diagonal blocks
                 igl = ( ibr-1 )*kbl + 1_ilp
                 loop_2010: do jbc = ibr + 1, nbl
                    jgl = ( jbc-1 )*kbl + 1_ilp
              ! doing the block at ( ibr, jbc )
                    ijblsk = 0_ilp
                    loop_2100: do p = igl, min( igl+kbl-1, n )
                       aapp = sva( p )
                       if( aapp>zero ) then
                          pskipped = 0_ilp
                          loop_2200: do q = jgl, min( jgl+kbl-1, n )
                             aaqq = sva( q )
                             if( aaqq>zero ) then
                                aapp0 = aapp
           ! M X 2 Jacobi Svd 
              ! safe gram matrix computation
                                if( aaqq>=one ) then
                                   if( aapp>=aaqq ) then
                                      rotok = ( small*aapp )<=aaqq
                                   else
                                      rotok = ( small*aaqq )<=aapp
                                   end if
                                   if( aapp<( big / aaqq ) ) then
                                      aapq = ( stdlib_cdotc( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aaqq ) / aapp
                                   else
                                      call stdlib_ccopy( m, a( 1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_clascl( 'G', 0_ilp, 0_ilp, aapp,one, m, 1_ilp,cwork(n+1), &
                                                lda, ierr )
                                      aapq = stdlib_cdotc( m, cwork(n+1), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aaqq
                                   end if
                                else
                                   if( aapp>=aaqq ) then
                                      rotok = aapp<=( aaqq / small )
                                   else
                                      rotok = aaqq<=( aapp / small )
                                   end if
                                   if( aapp>( small / aaqq ) ) then
                                      aapq = ( stdlib_cdotc( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp ) / max(&
                                                aaqq,aapp) )/ min(aaqq,aapp)
                                   else
                                      call stdlib_ccopy( m, a( 1_ilp, q ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_clascl( 'G', 0_ilp, 0_ilp, aaqq,one, m, 1_ilp,cwork(n+1), &
                                                lda, ierr )
                                      aapq = stdlib_cdotc( m, a( 1_ilp, p ), 1_ilp,cwork(n+1),  1_ilp ) / &
                                                aapp
                                   end if
                                end if
                                 ! aapq = aapq * conjg(cwork(p))*cwork(q)
                                aapq1  = -abs(aapq)
                                mxaapq = max( mxaapq, -aapq1 )
              ! to rotate or not to rotate, that is the question ...
                                if( abs( aapq1 )>tol ) then
                                   ompq = aapq / abs(aapq)
                                   notrot = 0_ilp
      ! [rtd]      rotated  = rotated + 1
                                   pskipped = 0_ilp
                                   iswrot = iswrot + 1_ilp
                                   if( rotok ) then
                                      aqoap = aaqq / aapp
                                      apoaq = aapp / aaqq
                                      theta = -half*abs( aqoap-apoaq )/ aapq1
                                      if( aaqq>aapp0 )theta = -theta
                                      if( abs( theta )>bigtheta ) then
                                         t  = half / theta
                                         cs = one
                                         call stdlib_crot( m, a(1_ilp,p), 1_ilp, a(1_ilp,q), 1_ilp,cs, conjg(ompq)&
                                                   *t )
                                         if( rsvec ) then
                                             call stdlib_crot( mvl, v(1_ilp,p), 1_ilp,v(1_ilp,q), 1_ilp, cs, &
                                                       conjg(ompq)*t )
                                         end if
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq1 ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq1 ) )
                                         mxsinj = max( mxsinj, abs( t ) )
                                      else
                       ! Choose Correct Signum For Theta And Rotate
                                         thsign = -sign( one, aapq1 )
                                         if( aaqq>aapp0 )thsign = -thsign
                                         t = one / ( theta+thsign*sqrt( one+theta*theta ) )
                                                   
                                         cs = sqrt( one / ( one+t*t ) )
                                         sn = t*cs
                                         mxsinj = max( mxsinj, abs( sn ) )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq1 ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq1 ) )
                                         call stdlib_crot( m, a(1_ilp,p), 1_ilp, a(1_ilp,q), 1_ilp,cs, conjg(ompq)&
                                                   *sn )
                                         if( rsvec ) then
                                             call stdlib_crot( mvl, v(1_ilp,p), 1_ilp,v(1_ilp,q), 1_ilp, cs, &
                                                       conjg(ompq)*sn )
                                         end if
                                      end if
                                      cwork(p) = -cwork(q) * ompq
                                   else
                    ! .. have to use modified gram-schmidt like transformation
                                    if( aapp>aaqq ) then
                                         call stdlib_ccopy( m, a( 1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp )
                                                   
                                         call stdlib_clascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, cwork(n+1)&
                                                   ,lda,ierr )
                                         call stdlib_clascl( 'G', 0_ilp, 0_ilp, aaqq, one,m, 1_ilp, a( 1_ilp, q ),&
                                                    lda,ierr )
                                         call stdlib_caxpy( m, -aapq, cwork(n+1),1_ilp, a( 1_ilp, q ), 1_ilp )
                                                   
                                         call stdlib_clascl( 'G', 0_ilp, 0_ilp, one, aaqq,m, 1_ilp, a( 1_ilp, q ),&
                                                    lda,ierr )
                                         sva( q ) = aaqq*sqrt( max( zero,one-aapq1*aapq1 ) )
                                                   
                                         mxsinj = max( mxsinj, sfmin )
                                    else
                                        call stdlib_ccopy( m, a( 1_ilp, q ), 1_ilp,cwork(n+1), 1_ilp )
                                         call stdlib_clascl( 'G', 0_ilp, 0_ilp, aaqq, one,m, 1_ilp, cwork(n+1)&
                                                   ,lda,ierr )
                                         call stdlib_clascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, a( 1_ilp, p ),&
                                                    lda,ierr )
                                         call stdlib_caxpy( m, -conjg(aapq),cwork(n+1), 1_ilp, a( 1_ilp, &
                                                   p ), 1_ilp )
                                         call stdlib_clascl( 'G', 0_ilp, 0_ilp, one, aapp,m, 1_ilp, a( 1_ilp, p ),&
                                                    lda,ierr )
                                         sva( p ) = aapp*sqrt( max( zero,one-aapq1*aapq1 ) )
                                                   
                                         mxsinj = max( mxsinj, sfmin )
                                    end if
                                   end if
                 ! end if rotok then ... else
                 ! in the case of cancellation in updating sva(q), sva(p)
                 ! .. recompute sva(q), sva(p)
                                   if( ( sva( q ) / aaqq )**2_ilp<=rooteps )then
                                      if( ( aaqq<rootbig ) .and.( aaqq>rootsfmin ) ) then
                                         sva( q ) = stdlib_scnrm2( m, a( 1_ilp, q ), 1_ilp)
                                       else
                                         t = zero
                                         aaqq = one
                                         call stdlib_classq( m, a( 1_ilp, q ), 1_ilp, t,aaqq )
                                         sva( q ) = t*sqrt( aaqq )
                                      end if
                                   end if
                                   if( ( aapp / aapp0 )**2_ilp<=rooteps ) then
                                      if( ( aapp<rootbig ) .and.( aapp>rootsfmin ) ) then
                                         aapp = stdlib_scnrm2( m, a( 1_ilp, p ), 1_ilp )
                                      else
                                         t = zero
                                         aapp = one
                                         call stdlib_classq( m, a( 1_ilp, p ), 1_ilp, t,aapp )
                                         aapp = t*sqrt( aapp )
                                      end if
                                      sva( p ) = aapp
                                   end if
                    ! end of ok rotation
                                else
                                   notrot = notrot + 1_ilp
      ! [rtd]      skipped  = skipped  + 1
                                   pskipped = pskipped + 1_ilp
                                   ijblsk = ijblsk + 1_ilp
                                end if
                             else
                                notrot = notrot + 1_ilp
                                pskipped = pskipped + 1_ilp
                                ijblsk = ijblsk + 1_ilp
                             end if
                             if( ( i<=swband ) .and. ( ijblsk>=blskip ) )then
                                sva( p ) = aapp
                                notrot = 0_ilp
                                go to 2011
                             end if
                             if( ( i<=swband ) .and.( pskipped>rowskip ) ) then
                                aapp = -aapp
                                notrot = 0_ilp
                                go to 2203
                             end if
                          end do loop_2200
              ! end of the q-loop
              2203 continue
                          sva( p ) = aapp
                       else
                          if( aapp==zero )notrot = notrot +min( jgl+kbl-1, n ) - jgl + 1_ilp
                          if( aapp<zero )notrot = 0_ilp
                       end if
                    end do loop_2100
           ! end of the p-loop
                 end do loop_2010
           ! end of the jbc-loop
           2011 continue
      ! 2011 bailed out of the jbc-loop
                 do p = igl, min( igl+kbl-1, n )
                    sva( p ) = abs( sva( p ) )
                 end do
      ! **
              end do loop_2000
      ! 2000 :: end of the ibr-loop
           ! .. update sva(n)
              if( ( sva( n )<rootbig ) .and. ( sva( n )>rootsfmin ) )then
                 sva( n ) = stdlib_scnrm2( m, a( 1_ilp, n ), 1_ilp )
              else
                 t = zero
                 aapp = one
                 call stdlib_classq( m, a( 1_ilp, n ), 1_ilp, t, aapp )
                 sva( n ) = t*sqrt( aapp )
              end if
           ! additional steering devices
              if( ( i<swband ) .and. ( ( mxaapq<=roottol ) .or.( iswrot<=n ) ) )swband = i
              if( ( i>swband+1 ) .and. ( mxaapq<sqrt( real( n,KIND=sp) )*tol ) .and. ( real( n,&
                        KIND=sp)*mxaapq*mxsinj<tol ) ) then
                 go to 1994
              end if
              if( notrot>=emptsw )go to 1994
           end do loop_1993
           ! end i=1:nsweep loop
       ! #:( reaching this point means that the procedure has not converged.
           info = nsweep - 1_ilp
           go to 1995
           1994 continue
       ! #:) reaching this point means numerical convergence after the i-th
           ! sweep.
           info = 0_ilp
       ! #:) info = 0 confirms successful iterations.
       1995 continue
           ! sort the singular values and find how many are above
           ! the underflow threshold.
           n2 = 0_ilp
           n4 = 0_ilp
           do p = 1, n - 1
              q = stdlib_isamax( n-p+1, sva( p ), 1_ilp ) + p - 1_ilp
              if( p/=q ) then
                 temp1 = sva( p )
                 sva( p ) = sva( q )
                 sva( q ) = temp1
                 call stdlib_cswap( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp, q ), 1_ilp )
                 if( rsvec )call stdlib_cswap( mvl, v( 1_ilp, p ), 1_ilp, v( 1_ilp, q ), 1_ilp )
              end if
              if( sva( p )/=zero ) then
                 n4 = n4 + 1_ilp
                 if( sva( p )*skl>sfmin )n2 = n2 + 1_ilp
              end if
           end do
           if( sva( n )/=zero ) then
              n4 = n4 + 1_ilp
              if( sva( n )*skl>sfmin )n2 = n2 + 1_ilp
           end if
           ! normalize the left singular vectors.
           if( lsvec .or. uctol ) then
              do p = 1, n4
                 ! call stdlib_csscal( m, one / sva( p ), a( 1, p ), 1 )
                 call stdlib_clascl( 'G',0_ilp,0_ilp, sva(p), one, m, 1_ilp, a(1_ilp,p), m, ierr )
              end do
           end if
           ! scale the product of jacobi rotations.
           if( rsvec ) then
                 do p = 1, n
                    temp1 = one / stdlib_scnrm2( mvl, v( 1_ilp, p ), 1_ilp )
                    call stdlib_csscal( mvl, temp1, v( 1_ilp, p ), 1_ilp )
                 end do
           end if
           ! undo scaling, if necessary (and possible).
           if( ( ( skl>one ) .and. ( sva( 1_ilp )<( big / skl ) ) ).or. ( ( skl<one ) .and. ( sva( &
                     max( n2, 1_ilp ) ) >( sfmin / skl ) ) ) ) then
              do p = 1, n
                 sva( p ) = skl*sva( p )
              end do
              skl = one
           end if
           rwork( 1_ilp ) = skl
           ! the singular values of a are skl*sva(1:n). if skl/=one
           ! then some of the singular values may overflow or underflow and
           ! the spectrum is given in this factored representation.
           rwork( 2_ilp ) = real( n4,KIND=sp)
           ! n4 is the number of computed nonzero singular values of a.
           rwork( 3_ilp ) = real( n2,KIND=sp)
           ! n2 is the number of singular values of a greater than sfmin.
           ! if n2<n, sva(n2:n) contains zeros and/or denormalized numbers
           ! that may carry some information.
           rwork( 4_ilp ) = real( i,KIND=sp)
           ! i is the index of the last sweep before declaring convergence.
           rwork( 5_ilp ) = mxaapq
           ! mxaapq is the largest absolute value of scaled pivots in the
           ! last sweep
           rwork( 6_ilp ) = mxsinj
           ! mxsinj is the largest absolute value of the sines of jacobi angles
           ! in the last sweep
           return
     end subroutine stdlib_cgesvj

     pure module subroutine stdlib_zgesvj( joba, jobu, jobv, m, n, a, lda, sva, mv, v,ldv, cwork, lwork, &
     !! ZGESVJ computes the singular value decomposition (SVD) of a complex
     !! M-by-N matrix A, where M >= N. The SVD of A is written as
     !! [++]   [xx]   [x0]   [xx]
     !! A = U * SIGMA * V^*,  [++] = [xx] * [ox] * [xx]
     !! [++]   [xx]
     !! where SIGMA is an N-by-N diagonal matrix, U is an M-by-N orthonormal
     !! matrix, and V is an N-by-N unitary matrix. The diagonal elements
     !! of SIGMA are the singular values of A. The columns of U and V are the
     !! left and the right singular vectors of A, respectively.
               rwork, lrwork, info )
        ! -- lapack computational routine --
        ! -- lapack is a software package provided by univ. of tennessee,    --
        ! -- univ. of california berkeley, univ. of colorado denver and nag ltd..--
           use stdlib_blas_constants_dp, only: negone, zero, half, one, two, three, four, eight, ten, czero, chalf, cone, cnegone
           ! Scalar Arguments 
           integer(ilp), intent(out) :: info
           integer(ilp), intent(in) :: lda, ldv, lwork, lrwork, m, mv, n
           character, intent(in) :: joba, jobu, jobv
           ! Array Arguments 
           complex(dp), intent(inout) :: a(lda,*), v(ldv,*), cwork(lwork)
           real(dp), intent(inout) :: rwork(lrwork)
           real(dp), intent(out) :: sva(n)
        ! =====================================================================
           ! Local Parameters 
           integer(ilp), parameter :: nsweep = 30_ilp
           
           
           
           ! Local Scalars 
           complex(dp) :: aapq, ompq
           real(dp) :: aapp, aapp0, aapq1, aaqq, apoaq, aqoap, big, bigtheta, cs, ctol, epsln, &
           mxaapq, mxsinj, rootbig, rooteps, rootsfmin, roottol, skl, sfmin, small, sn, t, temp1, &
                     theta, thsign, tol
           integer(ilp) :: blskip, emptsw, i, ibr, ierr, igl, ijblsk, ir1, iswrot, jbc, jgl, kbl, &
                     lkahead, mvl, n2, n34, n4, nbl, notrot, p, pskipped, q, rowskip, swband
           logical(lk) :: applv, goscale, lower, lquery, lsvec, noscale, rotok, rsvec, uctol, &
                     upper
           ! Intrinsic Functions 
           ! from lapack
           ! from lapack
           ! Executable Statements 
           ! test the input arguments
           lsvec = stdlib_lsame( jobu, 'U' ) .or. stdlib_lsame( jobu, 'F' )
           uctol = stdlib_lsame( jobu, 'C' )
           rsvec = stdlib_lsame( jobv, 'V' ) .or. stdlib_lsame( jobv, 'J' )
           applv = stdlib_lsame( jobv, 'A' )
           upper = stdlib_lsame( joba, 'U' )
           lower = stdlib_lsame( joba, 'L' )
           lquery = ( lwork == -1_ilp ) .or. ( lrwork == -1_ilp )
           if( .not.( upper .or. lower .or. stdlib_lsame( joba, 'G' ) ) ) then
              info = -1_ilp
           else if( .not.( lsvec .or. uctol .or. stdlib_lsame( jobu, 'N' ) ) ) then
              info = -2_ilp
           else if( .not.( rsvec .or. applv .or. stdlib_lsame( jobv, 'N' ) ) ) then
              info = -3_ilp
           else if( m<0_ilp ) then
              info = -4_ilp
           else if( ( n<0_ilp ) .or. ( n>m ) ) then
              info = -5_ilp
           else if( lda<m ) then
              info = -7_ilp
           else if( mv<0_ilp ) then
              info = -9_ilp
           else if( ( rsvec .and. ( ldv<n ) ) .or.( applv .and. ( ldv<mv ) ) ) then
              info = -11_ilp
           else if( uctol .and. ( rwork( 1_ilp )<=one ) ) then
              info = -12_ilp
           else if( ( lwork<( m+n ) ) .and. ( .not.lquery ) ) then
              info = -13_ilp
           else if( ( lrwork<max( n, 6_ilp ) ) .and. ( .not.lquery ) ) then
              info = -15_ilp
           else
              info = 0_ilp
           end if
           ! #:(
           if( info/=0_ilp ) then
              call stdlib_xerbla( 'ZGESVJ', -info )
              return
           else if ( lquery ) then
              cwork(1_ilp) = m + n
              rwork(1_ilp) = max( n, 6_ilp )
              return
           end if
       ! #:) quick return for void matrix
           if( ( m==0 ) .or. ( n==0 ) )return
           ! set numerical parameters
           ! the stopping criterion for jacobi rotations is
           ! max_{i<>j}|a(:,i)^* * a(:,j)| / (||a(:,i)||*||a(:,j)||) < ctol*eps
           ! where eps is the round-off and ctol is defined as follows:
           if( uctol ) then
              ! ... user controlled
              ctol = rwork( 1_ilp )
           else
              ! ... default
              if( lsvec .or. rsvec .or. applv ) then
                 ctol = sqrt( real( m,KIND=dp) )
              else
                 ctol = real( m,KIND=dp)
              end if
           end if
           ! ... and the machine dependent parameters are
      ! [!]  (make sure that stdlib_slamch() works properly on the target machine.)
           epsln = stdlib_dlamch( 'EPSILON' )
           rooteps = sqrt( epsln )
           sfmin = stdlib_dlamch( 'SAFEMINIMUM' )
           rootsfmin = sqrt( sfmin )
           small = sfmin / epsln
           big = stdlib_dlamch( 'OVERFLOW' )
           ! big         = one    / sfmin
           rootbig = one / rootsfmin
            ! large = big / sqrt( real( m*n,KIND=dp) )
           bigtheta = one / rooteps
           tol = ctol*epsln
           roottol = sqrt( tol )
           if( real( m,KIND=dp)*epsln>=one ) then
              info = -4_ilp
              call stdlib_xerbla( 'ZGESVJ', -info )
              return
           end if
           ! initialize the right singular vector matrix.
           if( rsvec ) then
              mvl = n
              call stdlib_zlaset( 'A', mvl, n, czero, cone, v, ldv )
           else if( applv ) then
              mvl = mv
           end if
           rsvec = rsvec .or. applv
           ! initialize sva( 1:n ) = ( ||a e_i||_2, i = 1:n )
      ! (!)  if necessary, scale a to protect the largest singular value
           ! from overflow. it is possible that saving the largest singular
           ! value destroys the information about the small ones.
           ! this initial scaling is almost minimal in the sense that the
           ! goal is to make sure that no column norm overflows, and that
           ! sqrt(n)*max_i sva(i) does not overflow. if infinite entries
           ! in a are detected, the procedure returns with info=-6.
           skl = one / sqrt( real( m,KIND=dp)*real( n,KIND=dp) )
           noscale = .true.
           goscale = .true.
           if( lower ) then
              ! the input matrix is m-by-n lower triangular (trapezoidal)
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_zlassq( m-p+1, a( p, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'ZGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           else if( upper ) then
              ! the input matrix is m-by-n upper triangular (trapezoidal)
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_zlassq( p, a( 1_ilp, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'ZGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           else
              ! the input matrix is m-by-n general dense
              do p = 1, n
                 aapp = zero
                 aaqq = one
                 call stdlib_zlassq( m, a( 1_ilp, p ), 1_ilp, aapp, aaqq )
                 if( aapp>big ) then
                    info = -6_ilp
                    call stdlib_xerbla( 'ZGESVJ', -info )
                    return
                 end if
                 aaqq = sqrt( aaqq )
                 if( ( aapp<( big / aaqq ) ) .and. noscale ) then
                    sva( p ) = aapp*aaqq
                 else
                    noscale = .false.
                    sva( p ) = aapp*( aaqq*skl )
                    if( goscale ) then
                       goscale = .false.
                       do q = 1, p - 1
                          sva( q ) = sva( q )*skl
                       end do
                    end if
                 end if
              end do
           end if
           if( noscale )skl = one
           ! move the smaller part of the spectrum from the underflow threshold
      ! (!)  start by determining the position of the nonzero entries of the
           ! array sva() relative to ( sfmin, big ).
           aapp = zero
           aaqq = big
           do p = 1, n
              if( sva( p )/=zero )aaqq = min( aaqq, sva( p ) )
              aapp = max( aapp, sva( p ) )
           end do
       ! #:) quick return for zero matrix
           if( aapp==zero ) then
              if( lsvec )call stdlib_zlaset( 'G', m, n, czero, cone, a, lda )
              rwork( 1_ilp ) = one
              rwork( 2_ilp ) = zero
              rwork( 3_ilp ) = zero
              rwork( 4_ilp ) = zero
              rwork( 5_ilp ) = zero
              rwork( 6_ilp ) = zero
              return
           end if
       ! #:) quick return for one-column matrix
           if( n==1_ilp ) then
              if( lsvec )call stdlib_zlascl( 'G', 0_ilp, 0_ilp, sva( 1_ilp ), skl, m, 1_ilp,a( 1_ilp, 1_ilp ), lda, ierr )
                        
              rwork( 1_ilp ) = one / skl
              if( sva( 1_ilp )>=sfmin ) then
                 rwork( 2_ilp ) = one
              else
                 rwork( 2_ilp ) = zero
              end if
              rwork( 3_ilp ) = zero
              rwork( 4_ilp ) = zero
              rwork( 5_ilp ) = zero
              rwork( 6_ilp ) = zero
              return
           end if
           ! protect small singular values from underflow, and try to
           ! avoid underflows/overflows in computing jacobi rotations.
           sn = sqrt( sfmin / epsln )
           temp1 = sqrt( big / real( n,KIND=dp) )
           if( ( aapp<=sn ) .or. ( aaqq>=temp1 ) .or.( ( sn<=aaqq ) .and. ( aapp<=temp1 ) ) ) &
                     then
              temp1 = min( big, temp1 / aapp )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq<=sn ) .and. ( aapp<=temp1 ) ) then
              temp1 = min( sn / aaqq, big / (aapp*sqrt( real(n,KIND=dp)) ) )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq>=sn ) .and. ( aapp>=temp1 ) ) then
              temp1 = max( sn / aaqq, temp1 / aapp )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else if( ( aaqq<=sn ) .and. ( aapp>=temp1 ) ) then
              temp1 = min( sn / aaqq, big / ( sqrt( real( n,KIND=dp) )*aapp ) )
               ! aaqq  = aaqq*temp1
               ! aapp  = aapp*temp1
           else
              temp1 = one
           end if
           ! scale, if necessary
           if( temp1/=one ) then
              call stdlib_dlascl( 'G', 0_ilp, 0_ilp, one, temp1, n, 1_ilp, sva, n, ierr )
           end if
           skl = temp1*skl
           if( skl/=one ) then
              call stdlib_zlascl( joba, 0_ilp, 0_ilp, one, skl, m, n, a, lda, ierr )
              skl = one / skl
           end if
           ! row-cyclic jacobi svd algorithm with column pivoting
           emptsw = ( n*( n-1 ) ) / 2_ilp
           notrot = 0_ilp
           do q = 1, n
              cwork( q ) = cone
           end do
           swband = 3_ilp
      ! [tp] swband is a tuning parameter [tp]. it is meaningful and effective
           ! if stdlib_zgesvj is used as a computational routine in the preconditioned
           ! jacobi svd algorithm stdlib_zgejsv. for sweeps i=1:swband the procedure
           ! works on pivots inside a band-like region around the diagonal.
           ! the boundaries are determined dynamically, based on the number of
           ! pivots above a threshold.
           kbl = min( 8_ilp, n )
      ! [tp] kbl is a tuning parameter that defines the tile size in the
           ! tiling of the p-q loops of pivot pairs. in general, an optimal
           ! value of kbl depends on the matrix dimensions and on the
           ! parameters of the computer's memory.
           nbl = n / kbl
           if( ( nbl*kbl )/=n )nbl = nbl + 1_ilp
           blskip = kbl**2_ilp
      ! [tp] blkskip is a tuning parameter that depends on swband and kbl.
           rowskip = min( 5_ilp, kbl )
      ! [tp] rowskip is a tuning parameter.
           lkahead = 1_ilp
      ! [tp] lkahead is a tuning parameter.
           ! quasi block transformations, using the lower (upper) triangular
           ! structure of the input matrix. the quasi-block-cycling usually
           ! invokes cubic convergence. big part of this cycle is done inside
           ! canonical subspaces of dimensions less than m.
           if( ( lower .or. upper ) .and. ( n>max( 64_ilp, 4_ilp*kbl ) ) ) then
      ! [tp] the number of partition levels and the actual partition are
           ! tuning parameters.
              n4 = n / 4_ilp
              n2 = n / 2_ilp
              n34 = 3_ilp*n4
              if( applv ) then
                 q = 0_ilp
              else
                 q = 1_ilp
              end if
              if( lower ) then
           ! this works very well on lower triangular matrices, in particular
           ! in the framework of the preconditioned jacobi svd (xgejsv).
           ! the idea is simple:
           ! [+ 0 0 0]   note that jacobi transformations of [0 0]
           ! [+ + 0 0]                                       [0 0]
           ! [+ + x 0]   actually work on [x 0]              [x 0]
           ! [+ + x x]                    [x x].             [x x]
                 call stdlib_zgsvj0( jobv, m-n34, n-n34, a( n34+1, n34+1 ), lda,cwork( n34+1 ), &
                 sva( n34+1 ), mvl,v( n34*q+1, n34+1 ), ldv, epsln, sfmin, tol,2_ilp, cwork( n+1 ), &
                           lwork-n, ierr )
                 call stdlib_zgsvj0( jobv, m-n2, n34-n2, a( n2+1, n2+1 ), lda,cwork( n2+1 ), sva( &
                 n2+1 ), mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 2_ilp,cwork( n+1 ), lwork-n, &
                           ierr )
                 call stdlib_zgsvj1( jobv, m-n2, n-n2, n4, a( n2+1, n2+1 ), lda,cwork( n2+1 ), &
                 sva( n2+1 ), mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 1_ilp,cwork( n+1 ), &
                           lwork-n, ierr )
                 call stdlib_zgsvj0( jobv, m-n4, n2-n4, a( n4+1, n4+1 ), lda,cwork( n4+1 ), sva( &
                 n4+1 ), mvl,v( n4*q+1, n4+1 ), ldv, epsln, sfmin, tol, 1_ilp,cwork( n+1 ), lwork-n, &
                           ierr )
                 call stdlib_zgsvj0( jobv, m, n4, a, lda, cwork, sva, mvl, v, ldv,epsln, sfmin, &
                           tol, 1_ilp, cwork( n+1 ), lwork-n,ierr )
                 call stdlib_zgsvj1( jobv, m, n2, n4, a, lda, cwork, sva, mvl, v,ldv, epsln, &
                           sfmin, tol, 1_ilp, cwork( n+1 ),lwork-n, ierr )
              else if( upper ) then
                 call stdlib_zgsvj0( jobv, n4, n4, a, lda, cwork, sva, mvl, v, ldv,epsln, sfmin, &
                           tol, 2_ilp, cwork( n+1 ), lwork-n,ierr )
                 call stdlib_zgsvj0( jobv, n2, n4, a( 1_ilp, n4+1 ), lda, cwork( n4+1 ),sva( n4+1 ), &
                 mvl, v( n4*q+1, n4+1 ), ldv,epsln, sfmin, tol, 1_ilp, cwork( n+1 ), lwork-n,ierr )
                           
                 call stdlib_zgsvj1( jobv, n2, n2, n4, a, lda, cwork, sva, mvl, v,ldv, epsln, &
                           sfmin, tol, 1_ilp, cwork( n+1 ),lwork-n, ierr )
                 call stdlib_zgsvj0( jobv, n2+n4, n4, a( 1_ilp, n2+1 ), lda,cwork( n2+1 ), sva( n2+1 )&
                 , mvl,v( n2*q+1, n2+1 ), ldv, epsln, sfmin, tol, 1_ilp,cwork( n+1 ), lwork-n, ierr )
                           
              end if
           end if
           ! .. row-cyclic pivot strategy with de rijk's pivoting ..
           loop_1993: do i = 1, nsweep
           ! .. go go go ...
              mxaapq = zero
              mxsinj = zero
              iswrot = 0_ilp
              notrot = 0_ilp
              pskipped = 0_ilp
           ! each sweep is unrolled using kbl-by-kbl tiles over the pivot pairs
           ! 1 <= p < q <= n. this is the first step toward a blocked implementation
           ! of the rotations. new implementation, based on block transformations,
           ! is under development.
              loop_2000: do ibr = 1, nbl
                 igl = ( ibr-1 )*kbl + 1_ilp
                 loop_1002: do ir1 = 0, min( lkahead, nbl-ibr )
                    igl = igl + ir1*kbl
                    loop_2001: do p = igl, min( igl+kbl-1, n-1 )
           ! .. de rijk's pivoting
                       q = stdlib_idamax( n-p+1, sva( p ), 1_ilp ) + p - 1_ilp
                       if( p/=q ) then
                          call stdlib_zswap( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp, q ), 1_ilp )
                          if( rsvec )call stdlib_zswap( mvl, v( 1_ilp, p ), 1_ilp,v( 1_ilp, q ), 1_ilp )
                          temp1 = sva( p )
                          sva( p ) = sva( q )
                          sva( q ) = temp1
                          aapq = cwork(p)
                          cwork(p) = cwork(q)
                          cwork(q) = aapq
                       end if
                       if( ir1==0_ilp ) then
              ! column norms are periodically updated by explicit
              ! norm computation.
      ! [!]     caveat:
              ! unfortunately, some blas implementations compute stdlib_dznrm2(m,a(1,p),1)
              ! as sqrt(s=stdlib_cdotc(m,a(1,p),1,a(1,p),1)), which may cause the result to
              ! overflow for ||a(:,p)||_2 > sqrt(overflow_threshold), and to
              ! underflow for ||a(:,p)||_2 < sqrt(underflow_threshold).
              ! hence, stdlib_dznrm2 cannot be trusted, not even in the case when
              ! the true norm is far from the under(over)flow boundaries.
              ! if properly implemented stdlib_scnrm2 is available, the if-then-else-end if
              ! below should be replaced with "aapp = stdlib_dznrm2( m, a(1,p), 1 )".
                          if( ( sva( p )<rootbig ) .and.( sva( p )>rootsfmin ) ) then
                             sva( p ) = stdlib_dznrm2( m, a( 1_ilp, p ), 1_ilp )
                          else
                             temp1 = zero
                             aapp = one
                             call stdlib_zlassq( m, a( 1_ilp, p ), 1_ilp, temp1, aapp )
                             sva( p ) = temp1*sqrt( aapp )
                          end if
                          aapp = sva( p )
                       else
                          aapp = sva( p )
                       end if
                       if( aapp>zero ) then
                          pskipped = 0_ilp
                          loop_2002: do q = p + 1, min( igl+kbl-1, n )
                             aaqq = sva( q )
                             if( aaqq>zero ) then
                                aapp0 = aapp
                                if( aaqq>=one ) then
                                   rotok = ( small*aapp )<=aaqq
                                   if( aapp<( big / aaqq ) ) then
                                      aapq = ( stdlib_zdotc( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aaqq ) / aapp
                                   else
                                      call stdlib_zcopy( m, a( 1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, cwork(n+1), &
                                                lda, ierr )
                                      aapq = stdlib_zdotc( m, cwork(n+1), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aaqq
                                   end if
                                else
                                   rotok = aapp<=( aaqq / small )
                                   if( aapp>( small / aaqq ) ) then
                                      aapq = ( stdlib_zdotc( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aapp ) / aaqq
                                   else
                                      call stdlib_zcopy( m, a( 1_ilp, q ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aaqq,one, m, 1_ilp,cwork(n+1), &
                                                lda, ierr )
                                      aapq = stdlib_zdotc( m, a(1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp ) / &
                                                aapp
                                   end if
                                end if
                                 ! aapq = aapq * conjg( cwork(p) ) * cwork(q)
                                aapq1  = -abs(aapq)
                                mxaapq = max( mxaapq, -aapq1 )
              ! to rotate or not to rotate, that is the question ...
                                if( abs( aapq1 )>tol ) then
                                ompq = aapq / abs(aapq)
                 ! Rotate
      ! [rtd]      rotated = rotated + one
                                   if( ir1==0_ilp ) then
                                      notrot = 0_ilp
                                      pskipped = 0_ilp
                                      iswrot = iswrot + 1_ilp
                                   end if
                                   if( rotok ) then
                                      aqoap = aaqq / aapp
                                      apoaq = aapp / aaqq
                                      theta = -half*abs( aqoap-apoaq )/aapq1
                                      if( abs( theta )>bigtheta ) then
                                         t  = half / theta
                                         cs = one
                                         call stdlib_zrot( m, a(1_ilp,p), 1_ilp, a(1_ilp,q), 1_ilp,cs, conjg(ompq)&
                                                   *t )
                                         if ( rsvec ) then
                                             call stdlib_zrot( mvl, v(1_ilp,p), 1_ilp,v(1_ilp,q), 1_ilp, cs, &
                                                       conjg(ompq)*t )
                                         end if
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq1 ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq1 ) )
                                         mxsinj = max( mxsinj, abs( t ) )
                                      else
                       ! Choose Correct Signum For Theta And Rotate
                                         thsign = -sign( one, aapq1 )
                                         t = one / ( theta+thsign*sqrt( one+theta*theta ) )
                                                   
                                         cs = sqrt( one / ( one+t*t ) )
                                         sn = t*cs
                                         mxsinj = max( mxsinj, abs( sn ) )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq1 ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq1 ) )
                                         call stdlib_zrot( m, a(1_ilp,p), 1_ilp, a(1_ilp,q), 1_ilp,cs, conjg(ompq)&
                                                   *sn )
                                         if ( rsvec ) then
                                             call stdlib_zrot( mvl, v(1_ilp,p), 1_ilp,v(1_ilp,q), 1_ilp, cs, &
                                                       conjg(ompq)*sn )
                                         end if
                                      end if
                                      cwork(p) = -cwork(q) * ompq
                                      else
                    ! .. have to use modified gram-schmidt like transformation
                                      call stdlib_zcopy( m, a( 1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aapp, one, m,1_ilp, cwork(n+1), &
                                                lda,ierr )
                                      call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aaqq, one, m,1_ilp, a( 1_ilp, q ), &
                                                lda, ierr )
                                      call stdlib_zaxpy( m, -aapq, cwork(n+1), 1_ilp,a( 1_ilp, q ), 1_ilp )
                                                
                                      call stdlib_zlascl( 'G', 0_ilp, 0_ilp, one, aaqq, m,1_ilp, a( 1_ilp, q ), &
                                                lda, ierr )
                                      sva( q ) = aaqq*sqrt( max( zero,one-aapq1*aapq1 ) )
                                      mxsinj = max( mxsinj, sfmin )
                                   end if
                 ! end if rotok then ... else
                 ! in the case of cancellation in updating sva(q), sva(p)
                 ! recompute sva(q), sva(p).
                                   if( ( sva( q ) / aaqq )**2_ilp<=rooteps )then
                                      if( ( aaqq<rootbig ) .and.( aaqq>rootsfmin ) ) then
                                         sva( q ) = stdlib_dznrm2( m, a( 1_ilp, q ), 1_ilp )
                                      else
                                         t = zero
                                         aaqq = one
                                         call stdlib_zlassq( m, a( 1_ilp, q ), 1_ilp, t,aaqq )
                                         sva( q ) = t*sqrt( aaqq )
                                      end if
                                   end if
                                   if( ( aapp / aapp0 )<=rooteps ) then
                                      if( ( aapp<rootbig ) .and.( aapp>rootsfmin ) ) then
                                         aapp = stdlib_dznrm2( m, a( 1_ilp, p ), 1_ilp )
                                      else
                                         t = zero
                                         aapp = one
                                         call stdlib_zlassq( m, a( 1_ilp, p ), 1_ilp, t,aapp )
                                         aapp = t*sqrt( aapp )
                                      end if
                                      sva( p ) = aapp
                                   end if
                                else
                                   ! a(:,p) and a(:,q) already numerically orthogonal
                                   if( ir1==0_ilp )notrot = notrot + 1_ilp
      ! [rtd]      skipped  = skipped + 1
                                   pskipped = pskipped + 1_ilp
                                end if
                             else
                                ! a(:,q) is zero column
                                if( ir1==0_ilp )notrot = notrot + 1_ilp
                                pskipped = pskipped + 1_ilp
                             end if
                             if( ( i<=swband ) .and.( pskipped>rowskip ) ) then
                                if( ir1==0_ilp )aapp = -aapp
                                notrot = 0_ilp
                                go to 2103
                             end if
                          end do loop_2002
           ! end q-loop
           2103 continue
           ! bailed out of q-loop
                          sva( p ) = aapp
                       else
                          sva( p ) = aapp
                          if( ( ir1==0_ilp ) .and. ( aapp==zero ) )notrot = notrot + min( igl+kbl-1, &
                                    n ) - p
                       end if
                    end do loop_2001
           ! end of the p-loop
           ! end of doing the block ( ibr, ibr )
                 end do loop_1002
           ! end of ir1-loop
       ! ... go to the off diagonal blocks
                 igl = ( ibr-1 )*kbl + 1_ilp
                 loop_2010: do jbc = ibr + 1, nbl
                    jgl = ( jbc-1 )*kbl + 1_ilp
              ! doing the block at ( ibr, jbc )
                    ijblsk = 0_ilp
                    loop_2100: do p = igl, min( igl+kbl-1, n )
                       aapp = sva( p )
                       if( aapp>zero ) then
                          pskipped = 0_ilp
                          loop_2200: do q = jgl, min( jgl+kbl-1, n )
                             aaqq = sva( q )
                             if( aaqq>zero ) then
                                aapp0 = aapp
           ! M X 2 Jacobi Svd 
              ! safe gram matrix computation
                                if( aaqq>=one ) then
                                   if( aapp>=aaqq ) then
                                      rotok = ( small*aapp )<=aaqq
                                   else
                                      rotok = ( small*aaqq )<=aapp
                                   end if
                                   if( aapp<( big / aaqq ) ) then
                                      aapq = ( stdlib_zdotc( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aaqq ) / aapp
                                   else
                                      call stdlib_zcopy( m, a( 1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aapp,one, m, 1_ilp,cwork(n+1), &
                                                lda, ierr )
                                      aapq = stdlib_zdotc( m, cwork(n+1), 1_ilp,a( 1_ilp, q ), 1_ilp ) / &
                                                aaqq
                                   end if
                                else
                                   if( aapp>=aaqq ) then
                                      rotok = aapp<=( aaqq / small )
                                   else
                                      rotok = aaqq<=( aapp / small )
                                   end if
                                   if( aapp>( small / aaqq ) ) then
                                      aapq = ( stdlib_zdotc( m, a( 1_ilp, p ), 1_ilp,a( 1_ilp, q ), 1_ilp ) / max(&
                                                aaqq,aapp) )/ min(aaqq,aapp)
                                   else
                                      call stdlib_zcopy( m, a( 1_ilp, q ), 1_ilp,cwork(n+1), 1_ilp )
                                      call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aaqq,one, m, 1_ilp,cwork(n+1), &
                                                lda, ierr )
                                      aapq = stdlib_zdotc( m, a( 1_ilp, p ), 1_ilp,cwork(n+1),  1_ilp ) / &
                                                aapp
                                   end if
                                end if
                                 ! aapq = aapq * conjg(cwork(p))*cwork(q)
                                aapq1  = -abs(aapq)
                                mxaapq = max( mxaapq, -aapq1 )
              ! to rotate or not to rotate, that is the question ...
                                if( abs( aapq1 )>tol ) then
                                   ompq = aapq / abs(aapq)
                                   notrot = 0_ilp
      ! [rtd]      rotated  = rotated + 1
                                   pskipped = 0_ilp
                                   iswrot = iswrot + 1_ilp
                                   if( rotok ) then
                                      aqoap = aaqq / aapp
                                      apoaq = aapp / aaqq
                                      theta = -half*abs( aqoap-apoaq )/ aapq1
                                      if( aaqq>aapp0 )theta = -theta
                                      if( abs( theta )>bigtheta ) then
                                         t  = half / theta
                                         cs = one
                                         call stdlib_zrot( m, a(1_ilp,p), 1_ilp, a(1_ilp,q), 1_ilp,cs, conjg(ompq)&
                                                   *t )
                                         if( rsvec ) then
                                             call stdlib_zrot( mvl, v(1_ilp,p), 1_ilp,v(1_ilp,q), 1_ilp, cs, &
                                                       conjg(ompq)*t )
                                         end if
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq1 ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq1 ) )
                                         mxsinj = max( mxsinj, abs( t ) )
                                      else
                       ! Choose Correct Signum For Theta And Rotate
                                         thsign = -sign( one, aapq1 )
                                         if( aaqq>aapp0 )thsign = -thsign
                                         t = one / ( theta+thsign*sqrt( one+theta*theta ) )
                                                   
                                         cs = sqrt( one / ( one+t*t ) )
                                         sn = t*cs
                                         mxsinj = max( mxsinj, abs( sn ) )
                                         sva( q ) = aaqq*sqrt( max( zero,one+t*apoaq*aapq1 ) )
                                                   
                                         aapp = aapp*sqrt( max( zero,one-t*aqoap*aapq1 ) )
                                         call stdlib_zrot( m, a(1_ilp,p), 1_ilp, a(1_ilp,q), 1_ilp,cs, conjg(ompq)&
                                                   *sn )
                                         if( rsvec ) then
                                             call stdlib_zrot( mvl, v(1_ilp,p), 1_ilp,v(1_ilp,q), 1_ilp, cs, &
                                                       conjg(ompq)*sn )
                                         end if
                                      end if
                                      cwork(p) = -cwork(q) * ompq
                                   else
                    ! .. have to use modified gram-schmidt like transformation
                                    if( aapp>aaqq ) then
                                         call stdlib_zcopy( m, a( 1_ilp, p ), 1_ilp,cwork(n+1), 1_ilp )
                                                   
                                         call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, cwork(n+1)&
                                                   ,lda,ierr )
                                         call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aaqq, one,m, 1_ilp, a( 1_ilp, q ),&
                                                    lda,ierr )
                                         call stdlib_zaxpy( m, -aapq, cwork(n+1),1_ilp, a( 1_ilp, q ), 1_ilp )
                                                   
                                         call stdlib_zlascl( 'G', 0_ilp, 0_ilp, one, aaqq,m, 1_ilp, a( 1_ilp, q ),&
                                                    lda,ierr )
                                         sva( q ) = aaqq*sqrt( max( zero,one-aapq1*aapq1 ) )
                                                   
                                         mxsinj = max( mxsinj, sfmin )
                                    else
                                        call stdlib_zcopy( m, a( 1_ilp, q ), 1_ilp,cwork(n+1), 1_ilp )
                                         call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aaqq, one,m, 1_ilp, cwork(n+1)&
                                                   ,lda,ierr )
                                         call stdlib_zlascl( 'G', 0_ilp, 0_ilp, aapp, one,m, 1_ilp, a( 1_ilp, p ),&
                                                    lda,ierr )
                                         call stdlib_zaxpy( m, -conjg(aapq),cwork(n+1), 1_ilp, a( 1_ilp, &
                                                   p ), 1_ilp )
                                         call stdlib_zlascl( 'G', 0_ilp, 0_ilp, one, aapp,m, 1_ilp, a( 1_ilp, p ),&
                                                    lda,ierr )
                                         sva( p ) = aapp*sqrt( max( zero,one-aapq1*aapq1 ) )
                                                   
                                         mxsinj = max( mxsinj, sfmin )
                                    end if
                                   end if
                 ! end if rotok then ... else
                 ! in the case of cancellation in updating sva(q), sva(p)
                 ! .. recompute sva(q), sva(p)
                                   if( ( sva( q ) / aaqq )**2_ilp<=rooteps )then
                                      if( ( aaqq<rootbig ) .and.( aaqq>rootsfmin ) ) then
                                         sva( q ) = stdlib_dznrm2( m, a( 1_ilp, q ), 1_ilp)
                                       else
                                         t = zero
                                         aaqq = one
                                         call stdlib_zlassq( m, a( 1_ilp, q ), 1_ilp, t,aaqq )
                                         sva( q ) = t*sqrt( aaqq )
                                      end if
                                   end if
                                   if( ( aapp / aapp0 )**2_ilp<=rooteps ) then
                                      if( ( aapp<rootbig ) .and.( aapp>rootsfmin ) ) then
                                         aapp = stdlib_dznrm2( m, a( 1_ilp, p ), 1_ilp )
                                      else
                                         t = zero
                                         aapp = one
                                         call stdlib_zlassq( m, a( 1_ilp, p ), 1_ilp, t,aapp )
                                         aapp = t*sqrt( aapp )
                                      end if
                                      sva( p ) = aapp
                                   end if
                    ! end of ok rotation
                                else
                                   notrot = notrot + 1_ilp
      ! [rtd]      skipped  = skipped  + 1
                                   pskipped = pskipped + 1_ilp
                                   ijblsk = ijblsk + 1_ilp
                                end if
                             else
                                notrot = notrot + 1_ilp
                                pskipped = pskipped + 1_ilp
                                ijblsk = ijblsk + 1_ilp
                             end if
                             if( ( i<=swband ) .and. ( ijblsk>=blskip ) )then
                                sva( p ) = aapp
                                notrot = 0_ilp
                                go to 2011
                             end if
                             if( ( i<=swband ) .and.( pskipped>rowskip ) ) then
                                aapp = -aapp
                                notrot = 0_ilp
                                go to 2203
                             end if
                          end do loop_2200
              ! end of the q-loop
              2203 continue
                          sva( p ) = aapp
                       else
                          if( aapp==zero )notrot = notrot +min( jgl+kbl-1, n ) - jgl + 1_ilp
                          if( aapp<zero )notrot = 0_ilp
                       end if
                    end do loop_2100
           ! end of the p-loop
                 end do loop_2010
           ! end of the jbc-loop
           2011 continue
      ! 2011 bailed out of the jbc-loop
                 do p = igl, min( igl+kbl-1, n )
                    sva( p ) = abs( sva( p ) )
                 end do
      ! **
              end do loop_2000
      ! 2000 :: end of the ibr-loop
           ! .. update sva(n)
              if( ( sva( n )<rootbig ) .and. ( sva( n )>rootsfmin ) )then
                 sva( n ) = stdlib_dznrm2( m, a( 1_ilp, n ), 1_ilp )
              else
                 t = zero
                 aapp = one
                 call stdlib_zlassq( m, a( 1_ilp, n ), 1_ilp, t, aapp )
                 sva( n ) = t*sqrt( aapp )
              end if
           ! additional steering devices
              if( ( i<swband ) .and. ( ( mxaapq<=roottol ) .or.( iswrot<=n ) ) )swband = i
              if( ( i>swband+1 ) .and. ( mxaapq<sqrt( real( n,KIND=dp) )*tol ) .and. ( real( n,&
                        KIND=dp)*mxaapq*mxsinj<tol ) ) then
                 go to 1994
              end if
              if( notrot>=emptsw )go to 1994
           end do loop_1993
           ! end i=1:nsweep loop
       ! #:( reaching this point means that the procedure has not converged.
           info = nsweep - 1_ilp
           go to 1995
           1994 continue
       ! #:) reaching this point means numerical convergence after the i-th
           ! sweep.
           info = 0_ilp
       ! #:) info = 0 confirms successful iterations.
       1995 continue
           ! sort the singular values and find how many are above
           ! the underflow threshold.
           n2 = 0_ilp
           n4 = 0_ilp
           do p = 1, n - 1
              q = stdlib_idamax( n-p+1, sva( p ), 1_ilp ) + p - 1_ilp
              if( p/=q ) then
                 temp1 = sva( p )
                 sva( p ) = sva( q )
                 sva( q ) = temp1
                 call stdlib_zswap( m, a( 1_ilp, p ), 1_ilp, a( 1_ilp, q ), 1_ilp )
                 if( rsvec )call stdlib_zswap( mvl, v( 1_ilp, p ), 1_ilp, v( 1_ilp, q ), 1_ilp )
              end if
              if( sva( p )/=zero ) then
                 n4 = n4 + 1_ilp
                 if( sva( p )*skl>sfmin )n2 = n2 + 1_ilp
              end if
           end do
           if( sva( n )/=zero ) then
              n4 = n4 + 1_ilp
              if( sva( n )*skl>sfmin )n2 = n2 + 1_ilp
           end if
           ! normalize the left singular vectors.
           if( lsvec .or. uctol ) then
              do p = 1, n4
                  ! call stdlib_zdscal( m, one / sva( p ), a( 1, p ), 1 )
                 call stdlib_zlascl( 'G',0_ilp,0_ilp, sva(p), one, m, 1_ilp, a(1_ilp,p), m, ierr )
              end do
           end if
           ! scale the product of jacobi rotations.
           if( rsvec ) then
                 do p = 1, n
                    temp1 = one / stdlib_dznrm2( mvl, v( 1_ilp, p ), 1_ilp )
                    call stdlib_zdscal( mvl, temp1, v( 1_ilp, p ), 1_ilp )
                 end do
           end if
           ! undo scaling, if necessary (and possible).
           if( ( ( skl>one ) .and. ( sva( 1_ilp )<( big / skl ) ) ).or. ( ( skl<one ) .and. ( sva( &
                     max( n2, 1_ilp ) ) >( sfmin / skl ) ) ) ) then
              do p = 1, n
                 sva( p ) = skl*sva( p )
              end do
              skl = one
           end if
           rwork( 1_ilp ) = skl
           ! the singular values of a are skl*sva(1:n). if skl/=one
           ! then some of the singular values may overflow or underflow and
           ! the spectrum is given in this factored representation.
           rwork( 2_ilp ) = real( n4,KIND=dp)
           ! n4 is the number of computed nonzero singular values of a.
           rwork( 3_ilp ) = real( n2,KIND=dp)
           ! n2 is the number of singular values of a greater than sfmin.
           ! if n2<n, sva(n2:n) contains zeros and/or denormalized numbers
           ! that may carry some information.
           rwork( 4_ilp ) = real( i,KIND=dp)
           ! i is the index of the last sweep before declaring convergence.
           rwork( 5_ilp ) = mxaapq
           ! mxaapq is the largest absolute value of scaled pivots in the
           ! last sweep
           rwork( 6_ilp ) = mxsinj
           ! mxsinj is the largest absolute value of the sines of jacobi angles
           ! in the last sweep
           return
     end subroutine stdlib_zgesvj



end submodule stdlib_lapack_eigv_svd_drivers2
