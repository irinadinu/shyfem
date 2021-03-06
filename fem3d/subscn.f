c
c $Id: subscn.f,v 1.7 2009-01-26 15:04:57 georg Exp $
c
c scanning procedures : scan string for numbers and convert them
c
c contents :
c
c function istof(line,f,ioff)			converts string to number
c function istod(line,d,ioff)			converts string to number
c function iscand(line,d,max)			converts string to numbers
c function iscanf(line,f,max)			converts string to numbers
c function iscan(line,ioff,f)			converts string to numbers
c function istos(line,string,ioff)		returns next string on line
c function iston(line,string,ioff)		returns next name on line
c
c function is_digit(c)				checks if c is digit
c function is_letter(c)				checks if c is letter
c
c function icindx(string,c)			finds c in string
c
c function idigit(value,ndec)			computes ciphers of number
c function lennum(string)			computes length of number
c subroutine alpha(ivalue,string)		converts integer to string
c function ialfa(value,string,ndec,mode)	converts real number into alpha
c
c function cindex(string,i)			returns i''th char of string
c subroutine skipwh(line,ioff)			skips white space
c
c function ideci(value)				computes pos after decimal point
c
c revision log :
c
c 01.06.1998	ggu	adapted from subsss.f and sbscan.f
c 31.05.1999	ggu	bug fix in ialfa -> negative numbers (idigs)
c 03.05.2001	ggu	bug fix in ialfa -> avoid -0.0 (MINUS0)
c 30.10.2001	ggu	bug fix for tab: not recognized as parameter
c 30.01.2002	ggu	bug fix for rounding 9.9 -> 10 for ndec=-1 (ROUND)
c 02.05.2012	ggu	new routine ideci()
c 20.02.2013	ggu	new routine iscand, istof changed to istod
c 06.02.2015	ggu	new routines istos,iston,is_digit,is_letter
c 15.04.2017	ggu	new routines istot
c 15.05.2017	ggu	bug fix in istod -> do not change ioff on error
c
c notes :
c
c	module scan
c
c	character*1,  parameter, private :: blank = ' '
c	character*1,  parameter, private :: tab = '	'
c	character*1,  parameter, private :: comma = ','
c	character*1,  parameter, private :: plus = '+'
c	character*1,  parameter, private :: minus = '-'
c	character*1,  parameter, private :: dot = '.'
c	character*4,  parameter, private :: expont = 'eEdD'
c	character*10, parameter, private :: number = '1234567890'
c
c	contains
c
c****************************************************************

	function istof(line,f,ioff)
	
	implicit none

	integer istof
	character*(*) line
	real f
	integer ioff

	double precision d
	integer istod

	istof = istod(line,d,ioff)
	f = d

	end

c****************************************************************

	function istod(line,d,ioff)

! converts string to number (reads exactly one number)
!
! a comma is treated like a blank (,, does not denote a value of 0)
!
! istod		1: valid number in d    0: EOL    -1: read error
! line		string to convert
! d		converted number (out)
! ioff		offset in string to start (in) 
!		position of first non blank char after number (out)

	implicit none

	integer istod
	character*(*) line
	double precision d
	integer ioff

	character*1  blank,tab,comma,plus,minus,dot
	character*4  expont
	character*10 number
	parameter(  blank = ' ' )
	!parameter(    tab = '	' )
	parameter(  comma = ',' )
	parameter(   plus = '+' )
	parameter(  minus = '-' )
	parameter(    dot = '.' )
	parameter( expont = 'eEdD' )
	parameter( number = '1234567890' )

	logical berr,beol,bnumb,bexp,bsign,besign,bdot
        logical bdebug
	integer i,n,istart,ic
	integer iesign,kexp
	double precision ff,fh,fact,sign
	character*1 c

	integer icindx
	
        bdebug = .false.

	tab = char(9)

	n=len(line)

! skip leading blanks

	i=ioff
	call skipwh(line,i)

! start reading number

	istart=i
	berr=.false.		!read error
	beol=i.gt.n		!end of line

	bnumb=.false.		!some number read
	bexp=.false.		!reading exponent
	bsign=.false.		!sign of number read
	besign=.false.		!sign of exponent read
	bdot=.false.		!decimal point read

	sign=1.0		!sign of number
	iesign=1		!sign of exponent

	ff=0.0			!number
	fact=1.			!factor for decimal part
	kexp=0			!exponent of number

	do i=istart,n

	c=line(i:i)

        if( bdebug ) write(6,*) 'istof: ',c,ichar(c)

	if( berr .or. c.eq.comma .or. c.eq.blank .or. c.eq.tab ) goto 1

	if( c.eq.plus ) then
		if( .not.bexp .and. .not.bsign ) then
			bsign=.true.
		else if( bexp .and. .not.besign ) then
			besign=.true.
		else
			berr=.true.
		end if
	else if( c.eq.minus ) then
		if( .not.bexp .and. .not.bsign ) then
			bsign=.true.
			sign=-1.
		else if( bexp .and. .not.besign ) then
			besign=.true.
			iesign=-1
		else
			berr=.true.
		end if
	else if( c.eq.dot ) then
		if( .not.bdot .and. .not.bexp ) then
			bdot=.true.
		else
			berr=.true.
		end if
	else if( icindx(expont,c) .gt. 0 ) then
		if( .not.bexp .and. bnumb ) then
			bexp=.true.
		else
			berr=.true.
		end if
	else
		ic=icindx(number,c)
		if( ic.eq.0 ) then
			berr=.true.
		else if( ic.eq.10 ) then
			ic=0
		end if
		fh=ic
		bnumb=.true.

		if( bexp ) then
			kexp = 10*kexp + ic
		else if( bdot ) then
			fact = 0.1*fact
			ff = ff + fact*fh
		else
			ff = 10.*ff + fh
		end if
	end if

        if( bdebug ) write(6,*) 'istof: ',ff,fact,kexp,ic,fh,berr

	end do

    1	continue

! skip trailing blanks

	call skipwh(line,i)

	if( beol ) then
		istod=0
		ioff=n+1
	else if( berr .or. .not.bnumb ) then
		istod=-1
		!ioff=istart-1
	else
		istod=1
		ioff=i
		d = ff * sign * ( 10.**(kexp*iesign) )
	end if

	end

!****************************************************************

	function iscand(line,d,max)

! converts string to numbers (reads at most max numbers)
!
! iscand	total number of numbers converted ( >0 )
!		0: blank line   <0: read error in |iscanf|'th number
! line		string to convert
! d		array of converted numbers (return)
! max		how many numbers to convert at most
!		 0: count only numbers in line
!		-1: convert all numbers found (default)

	implicit none

	integer iscand
	character*(*) line
	double precision d(*)
	integer max

	integer i,inumb,iret,maxf
	double precision ff

	integer istod

	maxf = max

	i=1
	inumb=0

	do while( .true. )
	  iret=istod(line,ff,i)
	  if( iret.le.0 ) exit
	  inumb=inumb+1
	  if( maxf.ne.0 ) d(inumb)=ff
	  if( inumb.eq.maxf ) exit
	end do

	if( iret.lt.0 ) inumb=-inumb-1

	iscand=inumb

	end

!****************************************************************

	function iscanf(line,f,max)

! converts string to numbers (reads at most max numbers)
!
! iscanf	total number of numbers converted ( >0 )
!		0: blank line   <0: read error in |iscanf|'th number
! line		string to convert
! f		array of converted numbers (return)
! max		how many numbers to convert at most
!		 0: count only numbers in line
!		-1: convert all numbers found (default)

	implicit none

	integer iscanf
	character*(*) line
	real f(*)
	integer max

	integer i,inumb,iret,maxf
	double precision ff

	integer istod

	maxf = max

	i=1
	inumb=0

	do while( .true. )
	  iret=istod(line,ff,i)
	  if( iret.le.0 ) exit
	  inumb=inumb+1
	  if( maxf.ne.0 ) f(inumb)=ff
	  if( inumb.eq.maxf ) exit
	end do

	if( iret.lt.0 ) inumb=-inumb-1

	iscanf=inumb

	end

!****************************************************************

	function iscan(line,ioff,f)

! converts string to numbers
!
! better use iscanf of iscand which gives the possibility to limit input
!
! iscan		total number of numbers converted ( >0 )
!		0: blank line   <0: read error in |iscanf|'th number
! line		string to convert
! ioff		offset in string
! f		array of converted numbers (return)

	implicit none

	integer iscan
	character*(*) line
	integer ioff
	real f(*)

	integer iscanf

	iscan = iscanf(line(ioff:),f,-1)

	end

!****************************************************************
!****************************************************************
!****************************************************************

	function istot(line,string,ioff)

c returns next token on line (text without blanks)
c
c > 0	success
c == 0	no text
c < 0	read or conversion error

	implicit none

	integer istot
	character*(*) line
	character*(*) string
	integer ioff

        character*1, save ::  blank = ' '
        character*1, save ::  tab = char(8)
        character*1, save ::  comma = ','

	character*1 c
	integer i,istart,iend
	integer ll,ls

	istot = 0
        string = ' '
	ll = len(line)
	ls = len(string)

	call skipwh(line,ioff)
	if( ioff > ll ) return

	istot = -1
        i = ioff
	istart = ioff

        do while( i < ll )
          i = i + 1
	  c = line(i:i)
          if( c == blank .or. c == tab .or. c == comma ) exit
	end do

	iend = i - 1
	if( i == ll ) iend = i

	if( iend-istart+1 > ls ) return		!string is too small for text

        string = line(istart:iend)
	ioff = iend + 1
	istot = 1

	end

!****************************************************************

	function istos(line,string,ioff)

c returns next string on line (text enclosed in "'" or '"')
c
c > 0	success
c == 0	no text
c < 0	read or conversion error

	implicit none

	integer istos
	character*(*) line
	character*(*) string
	integer ioff

	character*1 c
	logical bfound
	integer i,ia
	integer ll,ls

	istos = 0
        string = ' '
	ll = len(line)

	call skipwh(line,ioff)
	if( ioff > ll ) return

        c = line(ioff:ioff)
	if( c /= '"' .and. c /= "'" ) return	!no text found

	istos = -1
        ia = 0
        bfound = .false.
        i = ioff
	ls = len(string)

        do while( i < ll )
          i = i + 1
          if( line(i:i) == c ) then
            if( i < ll .and. line(i+1:i+1) == c ) then
              i = i + 1
            else
              bfound = .true.
              exit
            end if
          end if
          ia = ia + 1
	  if( ia > ls ) exit		!string is too small for text
          string(ia:ia) = line(i:i)
        end do

	ioff = i + 1
	if( bfound ) istos = 1

	end

!****************************************************************

	function iston(line,string,ioff)

c returns next name on line
c
c > 0	success
c == 0	no name
c < 0	read or conversion error

	implicit none

	integer iston
	character*(*) line
	character*(*) string	!contains name on return
	integer ioff

	character*1 c
	logical bgood
	integer i,ia
	integer ll,ls

	logical is_digit,is_letter

	iston = 0
        string = ' '
	ll = len(line)

	call skipwh(line,ioff)
	if( ioff > ll ) return

	c = line(ioff:ioff)
	if( .not. is_letter(c) ) return

	iston = -1
        ia = 0
        i = ioff
	ls = len(string)

        do
	  if( i > ll ) exit
	  c = line(i:i)
	  bgood = is_letter(c)
	  bgood = bgood .or. is_digit(c)
	  bgood = bgood .or. c == '_'
	  if( .not. bgood ) exit
          ia = ia + 1
	  if( ia > ls ) exit		!string is too small for text
          string(ia:ia) = line(i:i)
          i = i + 1
        end do

	ioff = i
	if( ia <= ls ) iston = 1

	end

!****************************************************************
!****************************************************************
!****************************************************************

	function is_digit(c)

c checks if c is digit

	implicit none

	logical is_digit
	character*1 c

	integer ia

	ia=ichar(c)

	is_digit = (ia.ge.48.and.ia.le.57)

	end

!****************************************************************

	function is_letter(c)

c checks if c is letter

	implicit none

	logical is_letter
	character*1 c

	integer ia

	ia=ichar(c)

	is_letter = (ia.ge.65.and.ia.le.90)
	is_letter = is_letter .or. (ia.ge.97.and.ia.le.122)

	end

!****************************************************************
!****************************************************************
!****************************************************************

	function icindx(string,c)

! finds c in string
!
! icindx	position of c in string ( 0 if not found )
! string	string where to look up c
! c		char to find

	implicit none

	integer icindx
	character*(*) string
	character*1 c

	integer i,n

	n=len(string)

	do i=1,n
	  if( string(i:i).eq.c ) goto 1
	end do

    1	continue
	if( i.gt.n ) then
	  icindx=0
	else
	  icindx=i
	end if

	end

!***********************************************************

	function idigit(value,ndec)

! computes ciphers of number
!
! idigit	ciphers of number z with minus sign and
!		...decimal point if necessary (return value)
! value		number for which ciphers have to be determined
! ndec		positions after the decimal point
!		(-1 : no decimal point)

	implicit none

	integer idigit
	real value
	integer ndec

	integer iz,istel

	istel=0

	iz=abs(value)+0.01
	if(iz.eq.0) istel=1
	if(value.lt.0.) istel=istel+1

	do while( .true. )
	  if(iz.le.0) goto 1
	  iz=iz/10
	  istel=istel+1
	end do

    1	continue

	if(ndec.ge.0) then
		istel=istel+1+ndec
	else if(ndec.lt.-1) then
		if(istel+1.lt.-ndec-1) then
			istel=istel+1
		else
			istel=-ndec-1
		end if
	end if

	idigit=istel

	end

!**********************************

	function lennum(string)

! computes length of number
!
! lennum	length of number (return value)
! string	string where the value is stored

	implicit none

	integer lennum
	character*(*) string

        character*1  blank,tab,comma,plus,minus,dot
        character*4  expont
        character*10 number
	parameter(  blank = ' ' )
	!parameter(    tab = '	' )
	parameter(  comma = ',' )
	parameter(   plus = '+' )
	parameter(  minus = '-' )
	parameter(    dot = '.' )
	parameter( expont = 'eEdD' )
	parameter( number = '1234567890' )

	character*1 c
	integer i

	tab = char(9)

	do i=1,len(string)
	  c=string(i:i)
	  if(c.eq.blank.or.c.eq.comma.or.c.eq.tab) goto 1
	end do

    1	continue

	lennum=i-1

	end

!********************************************

	subroutine alpha(ivalue,string)

! converts integer to string (always left justified)

	implicit none

	integer ivalue
	character*(*) string

	integer iaux
	integer ialfa

	iaux = ialfa(float(ivalue),string,-1,-1)

	end

!********************************************

	function ialfa(value,string,ndec,mode)

! converts real number into alphanumeric characters
! fills zahl with '*', if dimension of string is
! ...to small for zahl
!
! ialfa		total number of characters written to string
! value		number to be converted
! string	character string where value is written to
!		...(is filled with '*' if dimension of string
!		...is too small)
! ndec		ciphers after decimal point (-1 for no decimal point)
! mode		-1	left justified
!		 0	centred
!		 1	right justified

	implicit none

	integer ialfa
	character*(*) string
	real value
	integer ndec,mode

        character*1  blank,tab,comma,plus,minus,dot
        character*4  expont
        character*10 number
	parameter(  blank = ' ' )
	!parameter(    tab = '	' )
	parameter(  comma = ',' )
	parameter(   plus = '+' )
	parameter(  minus = '-' )
	parameter(    dot = '.' )
	parameter( expont = 'eEdD' )
	parameter( number = '1234567890' )

	integer lentxt,istell,is,ndif
	integer idigs
	integer i,j
	integer izi,izf,izahli,izahlf
	integer ifact
	real fact
	real zahl

	integer idigit
	character*1 cindex

	tab = char(9)

	lentxt=len(string)

c	istell=idigit(value,ndec)       !(ROUND)
c	idigs = istell			!remember for return value

	is=0
	zahl=value

!------ new --------------
c	if( ndec .gt. 0 ) then
	if( ndec .ge. 0 ) then          !(ROUND)
	  fact = 10**ndec
        else
	  fact = 10**(ndec+1)           !(ROUND)
        end if
	zahl = zahl * fact
c	if( zahl .gt. 0. ) then	!ggu changed 3/5/2001 to avoid -0.0
	if( zahl .ge. 0. ) then	!(MINUS0)
	  zahl = zahl + 0.5
	else
	  zahl = zahl - 0.5
	end if
	zahl = zahl / fact
!-------------------------

	istell=idigit(zahl,ndec)
	idigs = istell			!remember for return value

! number too long

	if(lentxt.lt.istell) then
		do i=1,lentxt
		  string(i:i)='*'
		end do
		ialfa=lentxt
		return
	end if

	if(zahl.lt.0) then
		is=1
		string(1:1)='-'
		istell=istell-1		!?????
		zahl=-zahl
	end if

! determine integer und fraction
!
! izi, izf		ciphers of i/f part
! izahli, izahlf	numbers of i/f part

	izi=istell-ndec-1
	if(ndec.gt.0) then
		izf=ndec
		ifact=10**ndec
c		izahli=(zahl*ifact+.5)/ifact    !(ROUND)
		izahli=(zahl*ifact)/ifact
		izahlf=(zahl-izahli)*ifact
	else
		izf=0
c		izahli=zahl+.5                  !(ROUND)
		izahli=zahl
		izahlf=0
	end if

! integer

	do i=izi,1,-1
	  j=mod(izahli,10)
	  if(j.eq.0) j=10
c	  string(is+i:is+i)=number(j:j)
	  string(is+i:is+i)=cindex(number,j)
	  izahli=izahli/10
	end do
	is=is+izi

! decimal point

	if(ndec.ge.0) then
		is=is+1
		string(is:is)='.'
	end if

! fraction

	do i=izf,1,-1
	  j=mod(izahlf,10)
	  if(j.eq.0) j=10
c	  string(is+i:is+i)=number(j:j)
	  string(is+i:is+i)=cindex(number,j)
	  izahlf=izahlf/10
	end do
	is=is+izf

! fill with blanks

	do i=is+1,lentxt
	  string(i:i)=' '
	end do

! justify text

	istell = idigs

	if(mode.gt.0) then
		ndif=lentxt-istell
	else if(mode.eq.0) then
		ndif=(lentxt-istell)/2
	else
		ndif=0
	end if

	do i=istell,1,-1
	   string(i+ndif:i+ndif)=string(i:i)
	end do

	if(ndif.ge.1) string(1:ndif)=' '
	if(istell+ndif.lt.lentxt) string(istell+ndif+1:lentxt)=' '

	ialfa=istell

	end

!****************************************************************

	function cindex(string,i)

c returns i''th character of string

	implicit none

	character*1 cindex
	character*(*) string
	integer i

	cindex = string(i:i)

	end

!****************************************************************

	subroutine skipwh(line,ioff)

c skips white space

	implicit none

	character*(*) line
	integer ioff

        character*1, save ::  blank = ' '
        character*1, save ::  tab = char(9)
        character*1, save ::  comma = ','

	integer n,istart,i
	character*1 c

	n = len(line)
	istart=ioff

	do i=istart,n
	  c=line(i:i)
	  if( c.ne.blank .and. c.ne.tab .and. c.ne.comma ) exit
	end do

	ioff = i

	end

!****************************************************************

	function ideci(value)

c computes positions after decimal point

	implicit none

	integer ideci
	real value

	integer n
	real eps,v

	eps=1.e-6

	n = 0
	v = value

	do while( abs(nint(v)-v) .gt. eps )
	  v = v * 10
	  n = n + 1
	end do

	if( n .le. 0 ) n = -1

	ideci = n

	end

!****************************************************************

!	end module scan

!****************************************************************

	subroutine scants

! tests scan routines

	implicit none

	real f(20)

	call scanpr("3.0 -4, 2.e-3 ,, -5",5,f)
	call scanpr("1 2 5r 6",2,f)
	call scanpr("1 2 5r 6",4,f)
	call scanpr("1 2 5r 6",0,f)
	call scanpr("1,3 5 -5   ,",7,f)
	call scanpr("1.0,2.0,5.0,6.0,7.0",0,f)
	call scanpr("1.0,2.0,5.0,6.0,7.0",-1,f)
	call scanpr("1.3.4   ",-1,f)
	call scanpr("  e+1   ",4,f)
	call scanpr("  .1  5.  .   ",-1,f)
	call scanpr("  .6e3  3.e-3  .e2   ",-1,f)
	call scanpr(" 4 5 test ",2,f)
	call scanpr("       ",2,f)

	end

!****************************************************************

	subroutine scanpr(line,max,f)

! test shell for iscanf : prints results of scan

	implicit none

	character*(*) line
	integer max
	real f(*)

	integer i,k
	integer iscanf

	i=iscanf(line,f,max)

	write(6,'(a)') '============================================='
	write(6,'(a)') line
	write(6,*) i,max
	if( i.lt.0 ) i=-i-1
	if(max.ne.0) write(6,*) (f(k),k=1,i)

	end

!****************************************************************
!	program scan
!	call scants
!	end
!****************************************************************

