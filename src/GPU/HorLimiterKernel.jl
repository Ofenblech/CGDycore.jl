
@kernel function LimitKernel!(DoF,qMin,qMax,@Const(Rhoq),@Const(Rho),@Const(Glob))

  iz = @index(Local, NTuple)
  Iz,IF,IT = @index(Global, NTuple)

  Nz = @uniform @ndrange()[1]
  NF = @uniform @ndrange()[2]
  NT = @uniform @ndrange()[3]


  @inbounds qMin[Iz,IF,IT] = eltype(Rhoq)(1/0)
  @inbounds qMax[Iz,IF,IT] = eltype(Rhoq)(-1/0)

  if Iz <= Nz && IF <= NF && IT <= NT
    for ID = 1 : DoF
      @inbounds ind = Glob[ID,IF]
      @inbounds qMin[Iz,IF,IT] = min(qMin[Iz,IF,IT],Rhoq[Iz,ind,IT] / Rho[Iz,ind])
      @inbounds qMax[Iz,IF,IT] = max(qMax[Iz,IF,IT],Rhoq[Iz,ind,IT] / Rho[Iz,ind])
    end
  end
end  

@kernel function DivRhoTrUpwind3LimKernel!(FTr,@Const(Tr),@Const(U),@Const(D),@Const(dXdxI),
  @Const(JJ),@Const(M),@Const(Glob),dt,@Const(w),@Const(qMin),@Const(qMax),@Const(Stencil))

# gi, gj, gz, gF = @index(Group, NTuple)
  I, J, iz   = @index(Local, NTuple)
  _,_,Iz,IF = @index(Global, NTuple)

  ColumnTilesDim = @uniform @groupsize()[3]
  N = @uniform @groupsize()[1]
  Nz = @uniform @ndrange()[3]
  NF = @uniform @ndrange()[4]

  @uniform l0  = eltype(FTr)(0)
  @uniform eta = eltype(FTr)(1.e-12)
  @uniform dlFD = eltype(FTr)(1.e-8)


  cCol = @localmem eltype(FTr) (N,N, ColumnTilesDim+3)
  uConCol = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  vConCol = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  DivRhoTr = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  DivRho = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  RhoTrColS = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  RhoColS = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  q = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  resp = @localmem eltype(FTr) (ColumnTilesDim)
  resc = @localmem eltype(FTr) (ColumnTilesDim)
  alpha = @localmem eltype(FTr) (ColumnTilesDim)
  lp = @localmem eltype(FTr) (ColumnTilesDim)
  lc = @localmem eltype(FTr) (ColumnTilesDim)
  sumJ = @localmem eltype(FTr) (ColumnTilesDim)
  qMinS = @localmem eltype(FTr) (ColumnTilesDim)
  qMaxS = @localmem eltype(FTr) (ColumnTilesDim)
  conv = @localmem (Bool) (ColumnTilesDim)
  if Iz <= Nz
    ID = I + (J - 1) * N  
    @inbounds ind = Glob[ID,IF]
    @inbounds cCol[I,J,iz+1] = Tr[Iz,ind] / U[Iz,ind,1]
    @views @inbounds (uCon, vCon) = Contra12(-U[Iz,ind,1],U[Iz,ind,2],U[Iz,ind,3],dXdxI[1:2,1:2,:,ID,Iz,IF])
    @inbounds uConCol[I,J,iz] = uCon
    @inbounds vConCol[I,J,iz] = vCon
    if ID == 1
      resp[iz] = eltype(FTr)(0)  
      resc[iz] = eltype(FTr)(0)  
      sumJ[iz] = eltype(FTr)(0)  
      conv[iz] = true
      qMinS[iz] = qMin[Iz,Stencil[IF,1]]
      qMaxS[iz] = qMax[Iz,Stencil[IF,1]]
      for iS = 2 : 13
        qMinS[iz] = min(qMin[Iz,Stencil[IF,iS]],qMinS[iz])
        qMaxS[iz] = max(qMax[Iz,Stencil[IF,iS]],qMaxS[iz])
      end
    end  
  end
  if iz == 1
    Izm1 = max(Iz - 1,1)
    cCol[I,J,iz] = Tr[Izm1,ind] / U[Izm1,ind,1]
  end
  if iz == ColumnTilesDim || Iz == Nz
    Izp1 = min(Iz + 1,Nz)
    cCol[I,J,iz+2] = Tr[Izp1,ind] / U[Izp1,ind,1]
    Izp2 = min(Iz + 2,Nz)
    cCol[I,J,iz+3] = Tr[Izp2,ind] / U[Izp2,ind,1]
  end
  @synchronize

  if Iz <= Nz 
    ID = I + (J - 1) * N  
    @inbounds @atomic sumJ[iz] += JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]  
  end
  @synchronize

  if Iz < Nz 
    ID = I + (J - 1) * N  
    @inbounds ind = Glob[ID,IF]
    @inbounds cLL = cCol[I,J,iz]
    @inbounds cL = cCol[I,J,iz+1]
    @inbounds cR = cCol[I,J,iz+2]
    @inbounds cRR = cCol[I,J,iz+3]

    @views @inbounds wCon = Contra3(U[Iz:Iz+1,ind,1],U[Iz:Iz+1,ind,2],U[Iz:Iz+1,ind,3],
      U[Iz,ind,4],dXdxI[3,:,:,ID,Iz:Iz+1,IF])

    Izm1 = max(Iz - 1,1)
    Izp2 = min(Iz + 2, Nz)
    @inbounds JLL = JJ[ID,1,Izm1,IF] + JJ[ID,2,Izm1,IF]
    @inbounds JL = JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]
    @inbounds JR = JJ[ID,1,Iz+1,IF] + JJ[ID,2,Iz+1,IF]
    @inbounds JRR = JJ[ID,1,Izp2,IF] + JJ[ID,2,Izp2,IF]
    cFL, cFR = RecU4(cLL,cL,cR,cRR,JLL,JL,JR,JRR) 
    Flux = eltype(FTr)(0.25) * ((abs(wCon) + wCon) * cFL + (-abs(wCon) + wCon) * cFR)
    @inbounds @atomic FTr[Iz,ind] += -Flux / M[Iz,ind]
    @inbounds @atomic FTr[Iz+1,ind] += Flux / M[Iz+1,ind]
  end 

  if Iz <= Nz
    ID = I + (J - 1) * N  
    @inbounds DivRhoTr[I,J,iz] = D[I,1] * uConCol[1,J,iz] * cCol[1,J,iz+1] 
    @inbounds DivRhoTr[I,J,iz] += D[J,1] * vConCol[I,1,iz] * cCol[I,1,iz+1]
    @inbounds DivRho[I,J,iz] = D[I,1] * uConCol[1,J,iz]
    @inbounds DivRho[I,J,iz] += D[J,1] * vConCol[I,1,iz]
    for k = 2 : N
      @inbounds DivRhoTr[I,J,iz] += D[I,k] * uConCol[k,J,iz] * cCol[k,J,iz+1] 
      @inbounds DivRhoTr[I,J,iz] += D[J,k] * vConCol[I,k,iz] * cCol[I,k,iz+1]
      @inbounds DivRho[I,J,iz] += D[I,k] * uConCol[k,J,iz]
      @inbounds DivRho[I,J,iz] += D[J,k] * vConCol[I,k,iz]
    end
    @inbounds ind = Glob[ID,IF]
    @inbounds RhoTrColS[I,J,iz] = Tr[Iz,ind] + dt * DivRhoTr[I,J,iz] / (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF])
    @inbounds RhoColS[I,J,iz] = U[Iz,ind,1] + dt * DivRho[I,J,iz] / (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF])
    #   Finite difference step
    @inbounds q[I,J,iz] = medianGPU(qMinS[iz], RhoTrColS[I,J,iz] / RhoColS[I,J,iz] +
      l0,  qMaxS[iz])
    @inbounds @atomic resp[iz] += (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]) * w[I] * w[J] / sumJ[iz] * 
      (q[I,J,iz] * RhoColS[I,J,iz] - RhoTrColS[I,J,iz])
  end
  @synchronize
  if Iz <= Nz
    ID = I + (J - 1) * N  
    if abs(resp[iz]) <= eta 
      if ID == 1
        @inbounds conv[iz] = false
      end  
    else
      @inbounds qLoc = medianGPU(qMinS[iz],  RhoTrColS[I,J,iz] / RhoColS[I,J,iz] + 
        (l0 + dlFD),  qMaxS[iz])
      @inbounds @atomic resc[iz] += (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]) * w[I] * w[J] / sumJ[iz] * 
        (qLoc * RhoColS[I,J,iz]  - RhoTrColS[I,J,iz])  
    end
  end
  @synchronize

  if Iz <= Nz && I == 1 && J == 1 && conv[iz]
    if abs(resc[iz] - resp[iz]) <= eltype(FTr)(1.e-13)
      @inbounds conv[iz] = false
    else
      @inbounds alpha[iz] = dlFD / (resc[iz] - resp[iz])
      @inbounds lp[iz] = l0
      @inbounds lc[iz] = lp[iz] - alpha[iz] * resp[iz]
      @inbounds resp[iz] = eltype(FTr)(0)
      @inbounds resc[iz] = eltype(FTr)(0)
    end
  end  
  @synchronize
  for iTer = 1 : 8
    if Iz <= Nz && conv[iz]
      ID = I + (J - 1) * N  
      @inbounds q[I,J,iz] = medianGPU(qMinS[iz], RhoTrColS[I,J,iz] / RhoColS[I,J,iz] +
        lc[iz],  qMaxS[iz])
      @inbounds @atomic resc[iz] += (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]) * w[I] * w[J] / sumJ[iz] *
        (q[I,J,iz] * RhoColS[I,J,iz] - RhoTrColS[I,J,iz])
    end  
    @synchronize
    if Iz <= Nz && I == 1 && J == 1 && conv[iz]
      if abs(resc[iz] - resp[iz]) <= eltype(FTr)(1.e-13) 
        @inbounds conv[iz] = false
      else  
        @inbounds alpha[iz] = (lp[iz] - lc[iz]) / (resp[iz] - resc[iz])
        @inbounds resp[iz] = resc[iz]
        @inbounds lp[iz] = lc[iz]
        @inbounds lc[iz] = lc[iz] - alpha[iz] * resc[iz]
        @inbounds resc[iz] = eltype(FTr)(0)  
      end  
    end  
    @synchronize
  end
  if Iz <= Nz
    ID = I + (J - 1) * N  
    @inbounds ind = Glob[ID,IF]
    @inbounds @atomic FTr[Iz,ind] += (q[I,J,iz] * RhoColS[I,J,iz] - Tr[Iz,ind]) *
      (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]) / dt / M[Iz,ind]
  end  
end

@kernel function DivRhoTrViscUpwind3LimKernel!(FTr,@Const(Tr),@Const(U),@Const(Cache),@Const(D),@Const(DW),@Const(dXdxI),
  @Const(JJ),@Const(M),@Const(Glob),Koeff,dt,@Const(w),@Const(qMin),@Const(qMax),@Const(Stencil))

  I, J, iz   = @index(Local, NTuple)
  _,_,Iz,IF = @index(Global, NTuple)

  ColumnTilesDim = @uniform @groupsize()[3]
  N = @uniform @groupsize()[1]
  Nz = @uniform @ndrange()[3]
  NF = @uniform @ndrange()[4]

  @uniform l0  = eltype(FTr)(0)
  @uniform eta = eltype(FTr)(1.e-12)
  @uniform dlFD = eltype(FTr)(1.e-8)

  cCol = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  CacheCol = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  RhoCol = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  uCol = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  vCol = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  wCol = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  DivRhoTr = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  DivRho = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  RhoTrColS = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  RhoColS = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  q = @localmem eltype(FTr) (N,N, ColumnTilesDim)
  resp = @localmem eltype(FTr) (ColumnTilesDim)
  resc = @localmem eltype(FTr) (ColumnTilesDim)
  alpha = @localmem eltype(FTr) (ColumnTilesDim)
  lp = @localmem eltype(FTr) (ColumnTilesDim)
  lc = @localmem eltype(FTr) (ColumnTilesDim)
  sumJ = @localmem eltype(FTr) (ColumnTilesDim)
  qMinS = @localmem eltype(FTr) (ColumnTilesDim)
  qMaxS = @localmem eltype(FTr) (ColumnTilesDim)
  conv = @localmem (Bool) (ColumnTilesDim)
  if Iz <= Nz
    ID = I + (J - 1) * N  
    @inbounds ind = Glob[ID,IF]
    @inbounds CacheCol[I,J,iz] = Cache[Iz,ind]
    @inbounds wCol[I,J,iz] = U[Iz,ind,4]
    @inbounds RhoCol[I,J,iz] = U[Iz,ind,1]
    @inbounds cCol[I,J,iz] = Tr[Iz,ind] / RhoCol[I,J,iz]
    @inbounds uCol[I,J,iz] = U[Iz,ind,2]
    @inbounds vCol[I,J,iz] = U[Iz,ind,3]
    @inbounds DivRho[I,J,iz] = eltype(FTr)(0)
    @inbounds DivRhoTr[I,J,iz] = eltype(FTr)(0)
    if ID == 1
      resp[iz] = eltype(FTr)(0)
      resc[iz] = eltype(FTr)(0)
      sumJ[iz] = eltype(FTr)(0)
      conv[iz] = true
      qMinS[iz] = minimum(qMin[Iz,Stencil[IF,:]])
      qMaxS[iz] = maximum(qMax[Iz,Stencil[IF,:]])
    end
  end
  @synchronize
  if Iz < Nz 
    ID = I + (J - 1) * N  
    @inbounds ind = Glob[ID,IF]
    @inbounds ind = Glob[ID,IF]
    @inbounds cL = cCol[I,J,iz]
    @inbounds cR = cCol[I,J,iz+1]
    if iz > 1
      @inbounds cLL = cCol[I,J,iz-1]
    else
      Izm1 = max(Iz - 1,1)
      @inbounds cLL = U[Izm1,ind,5] / U[Izm1,ind,1]
    end
    if iz < ColumnTilesDim - 1
      @inbounds cRR = cCol[I,J,iz+2]
    else
      Izp2 = min(Iz + 2, Nz)
      @inbounds cRR = U[Izp2,ind,5] / U[Izp2,ind,1]
    end

    @views @inbounds wCon = Contra3(U[Iz:Iz+1,ind,1],U[Iz:Iz+1,ind,2],U[Iz:Iz+1,ind,3],
      U[Iz,ind,4],dXdxI[3,:,:,ID,Iz:Iz+1,IF])

    Izm1 = max(Iz - 1,1)
    Izp2 = min(Iz + 2, Nz)
    @inbounds JLL = JJ[ID,1,Izm1,IF] + JJ[ID,2,Izm1,IF]
    @inbounds JL = JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]
    @inbounds JR = JJ[ID,1,Iz+1,IF] + JJ[ID,2,Iz+1,IF]
    @inbounds JRR = JJ[ID,1,Izp2,IF] + JJ[ID,2,Izp2,IF]
    cFL, cFR = RecU4(cLL,cL,cR,cRR,JLL,JL,JR,JRR) 
    Flux = 0.25 * ((abs(wCon) + wCon) * cFL + (-abs(wCon) + wCon) * cFR)
    @inbounds @atomic FTr[Iz,ind] += -Flux / M[Iz,ind]
    @inbounds @atomic FTr[Iz+1,ind] += Flux / M[Iz+1,ind]
  end

  if Iz <= Nz
    ID = I + (J - 1) * N  
    Dxc = 0
    Dyc = 0
    for k = 1 : N
      @inbounds Dxc = Dxc + D[I,k] * CacheCol[k,J,iz]
      @inbounds Dyc = Dyc + D[J,k] * CacheCol[I,k,iz]
    end
    
    @views @inbounds (GradDx, GradDy) = Grad12(RhoCol[I,J,iz],Dxc,Dyc,dXdxI[1:2,1:2,:,ID,Iz,IF],JJ[ID,:,Iz,IF])
    @views @inbounds (tempx, tempy) = Contra12(-Koeff,GradDx,GradDy,dXdxI[1:2,1:2,:,ID,Iz,IF])
    for k = 1 : N
      @inbounds @atomic DivRhoTr[k,J,iz] += DW[k,I] * tempx
      @inbounds @atomic DivRhoTr[I,k,iz] += DW[k,J] * tempy
    end

    @views @inbounds (tempxRho, tempyRho) = Contra12(-RhoCol[I,J,iz],uCol[I,J,iz],vCol[I,J,iz],dXdxI[1:2,1:2,:,ID,Iz,IF])
    for k = 1 : N
      @inbounds @atomic DivRho[k,J,iz] += D[k,I] * tempxRho
      @inbounds @atomic DivRho[I,k,iz] += D[k,J] * tempyRho
    end
    @inbounds tempxTr = tempxRho * cCol[I,J,iz]
    @inbounds tempyTr = tempyRho * cCol[I,J,iz]
    for k = 1 : N
      @inbounds @atomic DivRhoTr[k,J,iz] += D[k,I] * tempxTr
      @inbounds @atomic DivRhoTr[I,k,iz] += D[k,J] * tempyTr
    end
    @inbounds @atomic sumJ[iz] += JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]  
  end
  @synchronize

  if Iz <=Nz
    ID = I + (J - 1) * N  
    ind = Glob[ID,IF]  
    @inbounds RhoTrColS[I,J,iz] = Tr[Iz,ind] + dt * DivRhoTr[I,J,iz] / (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF])
    @inbounds RhoColS[I,J,iz] = U[Iz,ind,1] + dt * DivRho[I,J,iz] / (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF])
    #   Finite difference step
    @inbounds q[I,J,iz] = medianGPU(qMinS[iz], RhoTrColS[I,J,iz] / RhoColS[I,J,iz] +
      l0,  qMaxS[iz])
    @inbounds @atomic resp[iz] += (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]) * w[I] * w[J] / sumJ[iz] * 
      (q[I,J,iz] * RhoColS[I,J,iz] - RhoTrColS[I,J,iz])
  end
  @synchronize
  if Iz <= Nz
    ID = I + (J - 1) * N  
    if abs(resp[iz]) <= eta 
      if ID == 1
        @inbounds conv[iz] = false
      end  
    else
      @inbounds qLoc = medianGPU(qMinS[iz],  RhoTrColS[I,J,iz] / RhoColS[I,J,iz] + 
        (l0 + dlFD), qMaxS[iz])
      @inbounds @atomic resc[iz] += (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]) * w[I] * w[J] / sumJ[iz] * 
        (qLoc * RhoColS[I,J,iz]  - RhoTrColS[I,J,iz])  
    end
  end
  @synchronize

  if Iz <= Nz && I == 1 && J == 1 && conv[iz]
    if abs(resc[iz] - resp[iz]) <= eltype(FTr)(1.e-13)
      @inbounds conv[iz] = false
    else
      @inbounds alpha[iz] = dlFD / (resc[iz] - resp[iz])
      @inbounds lp[iz] = l0
      @inbounds lc[iz] = lp[iz] - alpha[iz] * resp[iz]
      @inbounds resp[iz] = eltype(FTr)(0)
      @inbounds resc[iz] = eltype(FTr)(0)
    end
  end  
  @synchronize
  for iTer = 1 : 5
    if Iz <= Nz && conv[iz]
      ID = I + (J - 1) * N  
      @inbounds q[I,J,iz] = medianGPU(qMinS[iz], RhoTrColS[I,J,iz] / RhoColS[I,J,iz] +
        lc[iz],  qMaxS[iz])
      @inbounds @atomic resc[iz] += (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]) * w[I] * w[J] / sumJ[iz] *
        (q[I,J,iz] * RhoColS[I,J,iz] - RhoTrColS[I,J,iz])
    end  
    @synchronize
    if Iz <= Nz && I == 1 && J == 1 && conv[iz]
      if abs(resc[iz] - resp[iz]) <= eltype(FTr)(1.e-13) 
        @inbounds conv[iz] = false
      else  
        @inbounds alpha[iz] = (lp[iz] - lc[iz]) / (resp[iz] - resc[iz])
        @inbounds resp[iz] = resc[iz]
        @inbounds lp[iz] = lc[iz]
        @inbounds lc[iz] = lc[iz] - alpha[iz] * resc[iz]
        @inbounds resc[iz] = eltype(FTr)(0)  
      end  
    end  
    @synchronize
  end
  if Iz <= Nz
    ID = I + (J - 1) * N  
    @inbounds ind = Glob[ID,IF]
    @inbounds @atomic FTr[Iz,ind] += (q[I,J,iz] * RhoColS[I,J,iz] - Tr[Iz,ind]) *
      (JJ[ID,1,Iz,IF] + JJ[ID,2,Iz,IF]) / dt / M[Iz,ind]
  end  
end

@inline function medianGPU(a1,a2,a3)
  if a1 <= a2
    if a2 <= a3
      m = a2
    elseif a1 <= a3
      m = a3
    else
      m = a1
    end
  else
    if a1 <= a3 
      m = a1
    elseif a2 <= a3
      m = a3
    else
      m = a2
    end
  end
end
