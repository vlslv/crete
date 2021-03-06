      SUBROUTINE getinputs(filein,fileout)

c (c) Michiel Hogerheijde / Floris van der Tak 2000
c     michiel@strw.leidenuniv.nl, vdtak@sron.nl
c     http://www.sron.rug.nl/~vdtak/ratran/
c
c     This file is part of the 'ratran' molecular excitation and
c     radiative transfer code. The one-dimensional version of this code
c     is publicly available; the two-dimensional version is available on
c     collaborative basis. Although the code has been thoroughly tested,
c     the authors do not claim that it is free of errors or that it gives
c     correct results in all situations. Any publication making use of
c     this code should include a reference to Hogerheijde & van der Tak,
c     2000, A&A 362, 697.

c     For revision history see http://www.sron.rug.nl/~vdtak/ratran/

c     Reads the input keywords, which are generated by the csh script.

      IMPLICIT NONE
      INCLUDE 'skycommon.inc'
      CHARACTER*200 line,keyw,valu
      CHARACTER*60 filein,fileout
      CHARACTER*80 molfile,fgfile,specref
      DOUBLE PRECISION xaem(maxline),energy(maxlev),gstat(maxlev)
     $     ,freq(maxline),eup(maxline)
      INTEGER xlal(maxline),xlau(maxline)
      INTEGER id,ilev,iline,iu,il,i,j,k,ifop,dummy
      DOUBLE PRECISION tkin(maxcell),amass,kappa,planck,dum,tau,tr,dv
      EXTERNAL kappa,planck
      INTEGER length
      EXTERNAL length
      LOGICAL debug
      PARAMETER (debug=.false.)

c     filein:    name of input file
c     fileout:   name of output file (prefix)
c     molfile:   name of molecular data file
c     fgfile:    foreground file (see documentation)
c     line:      used to read input keywords and parameters
c     keyw,valu: keyword and parameter value
c     id,iline,iu,il,i,j,k: counters
c     tkin:      kinetic temperature of source cells
c     amass:     molecular mass
c     kappa:     user-provided emissivity function
c     planck:    planck function
c     dum:       dummy variable
c     tau:       opacity read from fgfile
c     tr:        intensity in T_RJ read from fgfile
c     dv:        line width read from fgfile
c     debug:     turns debugging on/off

c     -------------------------------------------------------------------
      
      tcen=0                    ! Initialize
      incl=0
      tnorm=0
      fgfile=' '

   10 read(*,'(A200)',end=100) line ! Read from standard input

      do i=1,200                ! Split line in keyw and valu
        if (line(i:i).eq.'=') then
          do j=i+1,200
            if (line(j:j).eq.' ') goto 20
          enddo
          j=201
          goto 20
        endif
      enddo
      write(*,'(A)') 'SKY: cannot understand input'
      write(*,'(A)') line
      write(*,'(A)') 'SKY: skipping...'
      goto 10
   20 keyw=line(1:i-1)
      valu=line(i+1:j-1)
      if ((valu(1:1).eq.' ').or.(keyw(1:1).eq.' ')) then
        write(*,'(A)') 'SKY: cannot understand input'
        write(*,'(A)') line
        write(*,'(A)') 'SKY: skipping...'
        goto 10
      endif

c     Search keywords

      if (keyw(1:6).eq.'source') filein=valu(1:length(valu))
      if (keyw(1:3).eq.'out') fileout=valu(1:length(valu))
      if (keyw(1:3).eq.'nrx') read(valu,*) nrx
      if (keyw(1:5).eq.'trans') then
        j=1
        do k=1,nrx-1
          do i=j,200
            if (valu(i:i).eq.',') then
              goto 21
            endif
          enddo
   21     read(valu(j:i-1),*) trans(k)
          j=i+1
        enddo
        read(valu(j:200),*) trans(nrx)
      endif
      if (keyw(1:8).eq.'distance') read(valu,*) distance
      if (keyw(1:4).eq.'incl') read(valu,*) incl
      if (keyw(1:5).eq.'nchan') read(valu,*) nchan
      if (keyw(1:4).eq.'vres') read(valu,*) velres
      if (keyw(1:4).eq.'nsky') read(valu,*) nsky
      if (keyw(1:6).eq.'angres') read(valu,*) angres
      if (keyw(1:4).eq.'zoom') read(valu,*) zoom
      if (keyw(1:5).eq.'super') read(valu,*) super
      if (keyw(1:4).eq.'dcen') read(valu,*) dcen
      if (keyw(1:4).eq.'tcen') read(valu,*) tcen
      if (keyw(1:4).eq.'fgfg') fgfile=valu(1:length(valu))
      if (keyw(1:4).eq.'fvel') read(valu,*) fvel
      if (keyw(1:5).eq.'units') units=valu(1:length(valu))
      if (keyw(1:5).eq.'tnorm') read(valu,*) tnorm

      goto 10                   ! Next line/keyword

  100 distance=distance*pc      ! pc -> m
      incl=incl*pi/180.d0         ! degrees -> radians
      cosi=dcos(incl)
      sini=dsin(incl)
      velres=velres*1.d3        ! km/s -> m/s
      angres=angres/206264.806d0  ! arcsec -> radians
      dcen=dcen/206264.806d0      ! arcsec -> radians
      fvel=fvel*1.d3            ! km/s -> m/s

      xycen=dble(nsky)/2.d0     ! Central cell, channel
      vcen=int(nchan/2.d0)+1

c     Compare source size with sky grid:
      if (dmax1(rmax,zmax).ge.angres*distance*dble(nsky)/2.d0) then
        write(*,'(A)')
     $    ' WARNING: source may be larger than field of view!'
      endif

      if (debug) print*,'[debug] calling readmodel'

      call readmodel(filein,molfile,tkin) ! Read the source model

      if (debug) print*,'[debug] done readmodel'

      if (molfile.ne.'continuum') then
c     Get molecular parameters from molecular data file. Spectroscopy only!
        open(unit=11,file=molfile,status='old',err=999)

        if (debug) print*,'[debug] opened molfile'

c     Preamble
        read(11,*) 
        read(11,*) specref
        read(11,*) 
        read(11,*) amass
        amass=amass*amu
        read(11,*) 
        read(11,*) nlev

c     Term energies and statistical weights
        read(11,*)
        do ilev=1,nlev
           read(11,*) dummy,energy(ilev),gstat(ilev)
        enddo

c     Radiative upper & lower levels and Einstein coefficients
        read(11,*) 
        read(11,*) nline
        read(11,*)
        do iline=1,nline
           read(11,*) dummy,xlau(iline),xlal(iline),xaem(iline)
cc     $      ,freq(iline),eup(iline)  these are optional in the data file!
        enddo

        close(11)
        if (debug) print*,'[debug] finished with molfile'

        do j=1,nrx
          filter(j)=int(trans(j))
          lal(j)=xlal(filter(j))
          lau(j)=xlau(filter(j))
          nu(j)=(energy(lau(j))-energy(lal(j)))*100.d0*clight
          aeinst(j)=xaem(filter(j))
          beinstu(j)=aeinst(j)*(clight/nu(j))*(clight/nu(j))/
     $      (hplanck*nu(j))/2.d0
          beinstl(j)=gstat(xlau(filter(j)))/gstat(xlal(filter(j)))
     $         *beinstu(j)
        enddo

      else

c     Else trans contains the frequencies for continuum image(s)
c     Make sure that filter()=0 so that sky knows there are no lines

        do j=1,nrx
          nu(j)=trans(j)
          filter(j)=0
        enddo

      endif

      do i=1,nrx
        if ((units(1:1).eq.'K').or.(units(1:1).eq.'k')) 
     $    ucon(i)=(clight/nu(i))**2.d0/2.d0/kboltz
        if ((units(1:4).eq.'Jypx').or.(units(1:4).eq.'jypx'))
     $    ucon(i)=1.d26*angres*angres
        if ((units(1:7).eq.'Wm2Hzsr').or.(units(1:7).eq.'wm2hzsr'))
     $    ucon(i)=1.d0
c     1.9756d13 = sqrt(L_sun):
        if ((units(1:3).eq.'lnu').or.(units(1:3).eq.'Lnu'))
     $    ucon(i)=4.d0*pi*(distance/1.975d13)**2.d0*nu(i)*angres*angres
        if (tnorm.gt.0.) then
          norm(i)=planck(1,tnorm)
        else
          if (tbg.gt.0.) then
            norm(i)=planck(1,tbg)
          else
            norm(i)=planck(1,2.735d0)
          endif
        endif
        if (tbg.gt.0.) then
          cmb(i)=planck(i,tbg)/norm(i)
        else
          cmb(i)=0.d0
        endif
        if (tcen.gt.0) then
          cen(i)=planck(i,tcen)/norm(i)*pi*(dcen/angres)**2.d0
        else
          cen(i)=0.d0
        endif
      enddo

c     Add thermal contribution to line broadening
      if (molfile.ne.'continuum') then
        do i=1,ncell
          doppb(i)=dsqrt(doppb(i)**2.d0+2.d0*kboltz*tkin(i)/amass)
        enddo
      endif

c     Also initialize dust emissivity, converting from m2/kg_dust to "m-1"
c     ! Do not normalize dust; will be done in losintegr !

      do id=1,ncell
        do i=1,nrx
          knu(i,id)=kappa(id,nu(i))*2.4d0*amu/gas2dust*nh2(id)
          dust(i,id)=planck(i,tdust(id))
        enddo
      enddo


c     Read foreground file

      if (molfile.ne.'continuum') then
        do iline=1,nrx
          fgtau(iline)=0.d0
          fgtr(iline)=0.d0
        enddo
        fgdv=-1.
        if (fgfile(1:1).ne.' ') then
          open(3,file=fgfile,status='old')
          if (debug) print*,'[debug] opened fgfile'
          do iline=1,nrx
            rewind(3)
            do i=1,filter(iline)
              read(3,*) iu,il,dum,dum,dum,dum,dum,dv,dum,tau,dum,dum,tr
            enddo
            fgdv=dv*1.d3/1.665d0  ! km/s -> m/s and fwhm -> doppb
            fgtau(iline)=tau
c     T_RJ -> intensity:
            fgtr(iline)=tr*2.d0*kboltz*(nu(iline)/clight)**2.d0
     $        /norm(iline) 
          enddo
          close(3)
        endif
      endif


      RETURN

  999 stop 'Error opening molecular data file'

      END


