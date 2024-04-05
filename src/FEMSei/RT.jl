#RT0-RT2 for triangles
#RT0 for quads Todo RT1-RT2 for quads

mutable struct RT0Struct{FT<:AbstractFloat,
                      IT2<:AbstractArray} <: HDivElement
  Glob::IT2
  DoF::Int
  Comp::Int                      
  phi::Array{Polynomial,2}  
  Divphi::Array{Polynomial,2}                       
  NumG::Int
  NumI::Int
  Type::Grids.ElementType
  M::AbstractSparseMatrix
end

#RT0 Quad

function RT0Struct{FT}(::Grids.Quad,backend,Grid) where FT<:AbstractFloat
  Glob = KernelAbstractions.zeros(backend,Int,0,0)
  Type = Grids.Quad()
  DoF = 4
  Comp = 2
  @polyvar x1 x2
  phi = Array{Polynomial,2}(undef,DoF,Comp)
  Divphi = Array{Polynomial,2}(undef,DoF,1)
  phi[1,1] = 0.0*x1 + 0.0*x2
  phi[1,2] = -0.5 + 0.5*x2  + 0.0*x1

  phi[2,1] = 0.5 + 0.5*x1 + 0.0*x2
  phi[2,2] = 0*x1 + 0.0*x2

  phi[3,1] = 0*x1 + 0.0*x2
  phi[3,2] = -0.5 - 0.5*x2 + 0.0*x1

  phi[4,1] = 0.5 - 0.5*x1 + 0.0*x2
  phi[4,2] = 0*x1 + 0.0*x2

  for i = 1 : DoF
    Divphi[i,1] = differentiate(phi[i,1],x1) + differentiate(phi[i,2],x2)
  end

  Glob = KernelAbstractions.zeros(backend,Int,DoF,Grid.NumFaces)
  GlobCPU = zeros(Int,DoF,Grid.NumFaces)
  NumG = Grid.NumEdgesI + Grid.NumEdgesB
  NumI = Grid.NumEdgesI
  for iF = 1 : Grid.NumFaces
    for i = 1 : length(Grid.Faces[iF].E)
      iE = Grid.Faces[iF].E[i]
      GlobCPU[i,iF] = Grid.Edges[iE].E
    end
  end
  copyto!(Glob,GlobCPU)
  M = spzeros(0,0)
  return RT0Struct{FT,
                  typeof(Glob)}( 
  Glob,
  DoF,
  Comp,
  phi,                      
  Divphi,
  NumG,
  NumI,
  Type,
  M,
    )
  end

#RT0 Tri

function RT0Struct{FT}(type::Grids.Tri,backend,Grid) where FT<:AbstractFloat
  Glob = KernelAbstractions.zeros(backend,Int,0,0)
  Type = Grids.Quad()
  DoF = 3
  Comp = 2
  phi = Array{Polynomial,2}(undef,DoF,Comp) #base function of our used reference element
  nu = Array{Polynomial,2}(undef,DoF,Comp) #base function of standard reference element
  Divphi = Array{Polynomial,2}(undef,DoF,1)
  @polyvar x1 x2 ksi1 ksi2
  #Numbering 1-P(0,0), 2-P(-1,0), 3-P(0,-1) vertauschen zu 3-P(0,-1) 1-P(0,0) und 2-P(-1,0)
  nu[2,1] = 0.0 + 1.0*ksi1 + 0.0*ksi2
  nu[2,2] = 0.0 + 1.0*ksi2 + 0.0*ksi1

  nu[3,1] = +1.0 - 1.0*ksi1 + 0.0*ksi2
  nu[3,2] = 0.0 - 1.0*ksi2 + 0.0*ksi1

  nu[1,1] = 0.0 + 1.0*ksi1 + 0.0*ksi2
  nu[1,2] = -1.0 + 1.0*ksi2 + 0.0*ksi1

  for s = 1 : DoF
    for t = 1 : 2
      phi[s,t] = subs(nu[s,t], ksi1 => (x1+1)/2, ksi2 => (x2+1)/2)
    end
  end

  for i = 1 : DoF
    Divphi[i,1] = differentiate(phi[i,1],x1) + differentiate(phi[i,2],x2)
  end


  Glob = KernelAbstractions.zeros(backend,Int,DoF,Grid.NumFaces)
  GlobCPU = zeros(Int,DoF,Grid.NumFaces)
  NumG = Grid.NumEdgesI + Grid.NumEdgesB
  NumI = Grid.NumEdgesI
  for iF = 1 : Grid.NumFaces
    for i = 1 : length(Grid.Faces[iF].E)
      iE = Grid.Faces[iF].E[i]
      GlobCPU[i,iF] = Grid.Edges[iE].E
    end
  end
  copyto!(Glob,GlobCPU)
  M = spzeros(0,0)
  return RT0Struct{FT,
                  typeof(Glob)}( 
    Glob,
    DoF,
    Comp,
    phi,
    Divphi,                      
    NumG,
    NumI,
    Type,
    M,
      )
end

mutable struct RT1Struct{FT<:AbstractFloat,
                      IT2<:AbstractArray} <: HDivElement
  Glob::IT2
  DoF::Int
  Comp::Int                      
  phi::Array{Polynomial,2}  
  Divphi::Array{Polynomial,2}                       
  NumG::Int
  NumI::Int
  Type::Grids.ElementType
  M::AbstractSparseMatrix
end

#RT1 QuadTODO

function RT1Struct{FT}(::Grids.Quad,backend,Grid) where FT<:AbstractFloat
  Glob = KernelAbstractions.zeros(backend,Int,0,0)
  Type = Grids.Quad()
  DoF = 12
  Comp = 2
  phi = Array{Polynomial,2}(undef,DoF,Comp) 
  nu = Array{Polynomial,2}(undef,DoF,Comp)
  Divphi = Array{Polynomial,2}(undef,DoF,1)
  @polyvar x1 x2 ksi1 ksi2
  
  nu[1,1] = 0
  nu[1,1] = -18*ksi1*ksi2^2 + 24*ksi1*ksi2 - 6*ksi1 + 12*ksi2^2 - 16*ksi2 + 4

  nu[2,1] = 0
  nu[2,1] = 18*ksi1*ksi2^2 - 24*ksi1*ksi2 + 6*ksi1 - 6*ksi2^2 + 8*ksi2 - 2

  nu[3,1] = 18*ksi1^2*ksi2 - 12*ksi1^2 - 24*ksi1*ksi2 + 16*ksi1 + 6*ksi2 - 4
  nu[3,1] = 0

  nu[4,1] = -18*ksi1^2*ksi2 + 6*ksi1^2 + 24*ksi1*ksi2 - 8*ksi1 - 6*ksi2 + 2
  nu[4,1] = 0

  nu[5,1] = 18*ksi1^2*ksi2 - 12*ksi1^2 - 12*ksi1*ksi2 + 8*ksi1
  nu[5,1] = 0

  nu[6,1] = -18*ksi1^2*ksi2 + 6*ksi1^2 + 12*ksi1*ksi2 - 4*ksi1
  nu[6,1] = 0

  nu[7,1] = 0
  nu[7,1] = -18*ksi1*ksi2^2 + 12*ksi1*ksi2 + 12*ksi2^2 - 8*ksi2

  nu[8,1] = 0
  nu[8,1] = 18*ksi1*ksi2^2 - 12*ksi1*ksi2 - 6*ksi2^2 + 4*ksi2

  nu[9,1] = 36*ksi1^2*ksi2 - 24*ksi1^2 - 36*ksi1*ksi2 + 24*ksi1
  nu[9,1] = 0

  nu[10,1] = 0
  nu[10,1] =  36*ksi1*ksi2^2 - 36*ksi1*ksi2 - 24*ksi2^2 + 24*ksi2

  nu[11,1] =  0
  nu[11,1] =  -36*ksi1*ksi2^2 + 36*ksi1*ksi2 + 12*ksi2^2 - 12*ksi2

  nu[12,1] =  -36*ksi1^2*ksi2 + 12*ksi1^2 + 36*ksi1*ksi2 - 12*ksi1
  nu[12,1] =  0

  for s = 1 : DoF
    for t = 1 : 2
      phi[s,t] = subs(nu[s,t], ksi1 => (x1+1)/2, ksi2 => (x2+1)/2)
    end
  end
  
  for i = 1 : DoF
    Divphi[i,1] = differentiate(phi[i,1],x1) + differentiate(phi[i,2],x2)
  end

  Glob = KernelAbstractions.zeros(backend,Int,DoF,Grid.NumFaces)
  GlobCPU = zeros(Int,DoF,Grid.NumFaces)
  NumG = Grid.NumEdgesI + Grid.NumEdgesB
  NumI = Grid.NumEdgesI
  for iF = 1 : Grid.NumFaces
    for i = 1 : length(Grid.Faces[iF].E)
      iE = Grid.Faces[iF].E[i]
      GlobCPU[i,iF] = Grid.Edges[iE].E
    end
  end
  copyto!(Glob,GlobCPU)
  M = spzeros(0,0)
  return RT1Struct{FT,
                  typeof(Glob)}( 
    Glob,
    DoF,
    Comp,
    phi,                      
    Divphi,
    NumG,
    NumI,
    Type,
    M,
      )
  end

#RT1 Tri

function RT1Struct{FT}(type::Grids.Tri,backend,Grid) where FT<:AbstractFloat
  Glob = KernelAbstractions.zeros(backend,Int,0,0)
  Type = Grids.Tri()
  DoF = 8
  Comp = 2
  phi = Array{Polynomial,2}(undef,DoF,Comp)
  Divphi = Array{Polynomial,2}(undef,DoF,1)
  @polyvar x1 x2

  phi[1,1] = -(x2^2) - x2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2
  phi[1,2] = -0.5 - 0.5*x2 - x1 - x1*x2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2

  phi[2,1] = -x1*x2 - x1/2 - x2 - 1/2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2
  phi[2,2] = -x2^2-x2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2

  phi[3,1] = -x1^2 - x1*x2 + x2/2 + 1/2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2
  phi[3,2] = -x1*x2 - x1 - x2^2 - 3*x2/2 - 1/2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2

  phi[4,1] = x1*x2 + x1/2 - x2/2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2
  phi[4,2] = x2^2 + x2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2

  phi[5,1] = x1^2 + x1*x2 + 3*x1/2 + x2 + 1/2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2
  phi[5,2] = x1*x2 - x1/2 + x2^2 - 1/2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2

  phi[6,1] = -x1^2 - x1 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2
  phi[6,2] = -x1*x2 + x1/2 - x2/2 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2

  #non-normal

  phi[7,1] = -2*x1^2 - x1*x2 - x1 - x2 + 1 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2
  phi[7,2] = -2*x1*x2 - 2*x1 - x2^2 - 2*x2 - 1 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2

  phi[8,1] = -x1^2 - 2*x1*x2 - 2*x1 - 2*x2 - 1 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2
  phi[8,2] = -x1*x2 - x1 - 2*x2^2 - x2 + 1 + 0.0x1 + 0.0x2 + 0.0x1^2 + 0.0x2^2 + 0.0x1*x2

  for i = 1 : DoF
    Divphi[i,1] = differentiate(phi[i,1],x1) + differentiate(phi[i,2],x2)
  end

  Glob = KernelAbstractions.zeros(backend,Int,DoF,Grid.NumFaces)
  GlobCPU = zeros(Int,DoF,Grid.NumFaces)
  NumG = Grid.NumEdgesI + Grid.NumEdgesB
  NumI = Grid.NumEdgesI
  for iF = 1 : Grid.NumFaces
    for i = 1 : length(Grid.Faces[iF].E)
      iE = Grid.Faces[iF].E[i]
      GlobCPU[i,iF] = Grid.Edges[iE].E
    end
  end
  copyto!(Glob,GlobCPU)
  M = spzeros(0,0)
  return RT1Struct{FT,
                  typeof(Glob)}( 
    Glob,
    DoF,
    Comp,
    phi,
    Divphi,                      
    NumG,
    NumI,
    Type, 
    M,
      )
  end

mutable struct RT2Struct{FT<:AbstractFloat,
                      IT2<:AbstractArray} <: HDivElement
  Glob::IT2
  DoF::Int
  Comp::Int                      
  phi::Array{Polynomial,2}  
  Divphi::Array{Polynomial,2}                       
  NumG::Int
  NumI::Int
  Type::Grids.ElementType
  M::AbstractSparseMatrix
end

#RT2 Tri

function RT2Struct{FT}(type::Grids.Tri,backend,Grid) where FT<:AbstractFloat
  Glob = KernelAbstractions.zeros(backend,Int,0,0)
  Type = Grids.Tri()
  DoF = 15
  Comp = 2
  phi = Array{Polynomial,2}(undef,DoF,Comp)
  Divphi = Array{Polynomial,2}(undef,DoF,1)
  @polyvar x1 x2
    
  phi[1,1] = -45*x1^3/16 - 45*x1^2/16 + 9*x1/16 + 9/16
  phi[1,2] = -45*x1^2*x2/16 - 45*x1^2/16 - 15*x1*x2/8 - 15*x1/8 + 3*x2/16 + 3/16
    
  phi[2,1] = -45*x1*x2^2/16 - 15*x1*x2/8 + 3*x1/16 - 45*x2^2/16 - 15*x2/8 + 3/16
  phi[2,2] = -45*x2^3/16 - 45*x2^2/16 + 9*x2/16 + 9/16
    
  phi[3,1] = -45*x1^3/64 - 45*x1^2*x2/16 - 165*x1^2/64 - 45*x1*x2^2/64 - 135*x1*x2/32 - 39*x1/16 - 45*x2^2/64 - 45*x2/32 - 9/16
  phi[3,2] = -45*x1^2*x2/64 - 45*x1^2/64 - 45*x1*x2^2/16 - 135*x1*x2/32 - 45*x1/32 - 45*x2^3/64 - 165*x2^2/64 - 39*x2/16 - 9/16
    
  phi[4,1] = 45*x1^3/16 + 45*x1^2*x2/8 + 45*x1^2/16 + 45*x1*x2^2/16 + 15*x1*x2/8 - 3*x1/2 - 15*x2^2/16 - 9*x2/4 - 3/4
  phi[4,2] = 45*x1^2*x2/16 + 45*x1^2/16 + 45*x1*x2^2/8 + 75*x1*x2/8 + 15*x1/4 + 45*x2^3/16 + 105*x2^2/16 + 9*x2/2 + 3/4
    
  phi[5,1] = 45*x1*x2^2/16 + 15*x1*x2/8 - 3*x1/16 - 15*x2^2/16 + 3*x2/8 + 9/16
  phi[5,2] = 45*x2^3/16 + 45*x2^2/16 - 9*x2/16 - 9/16
    
  phi[6,1] = 45*x1^3/64 - 45*x1^2*x2/32 - 75*x1^2/64 - 45*x1*x2^2/32 - 15*x1*x2/16 - 39*x1/64 + 15*x2^2/32 + 15*x2/32 + 9/64
  phi[6,2] = 45*x1^2*x2/64 + 45*x1^2/64 - 45*x1*x2^2/32 - 45*x1*x2/32 - 45*x2^3/32 - 75*x2^2/32 - 69*x2/64 - 9/64

  phi[7,1] = -45*x1^3/16 - 45*x1^2*x2/8 - 105*x1^2/16 - 45*x1*x2^2/16 - 75*x1*x2/8 - 9*x1/2 - 45*x2^2/16 - 15*x2/4 - 3/4
  phi[7,2] = -45*x1^2*x2/16 + 15*x1^2/16 - 45*x1*x2^2/8 - 15*x1*x2/8 + 9*x1/4 - 45*x2^3/16 - 45*x2^2/16 + 3*x2/2 + 3/4
    
  phi[8,1] = -45*x1^3/16 - 45*x1^2/16 + 9*x1/16 + 9/16
  phi[8,2] = -45*x1^2*x2/16 + 15*x1^2/16 - 15*x1*x2/8 - 3*x1/8 + 3*x2/16 - 9/16

  phi[9,1] = 45*x1^3/32 + 45*x1^2*x2/32 + 75*x1^2/32 - 45*x1*x2^2/64 + 45*x1*x2/32 + 69*x1/64 - 45*x2^2/64 + 9/64
  phi[9,2] = 45*x1^2*x2/32 - 15*x1^2/32 + 45*x1*x2^2/32 + 15*x1*x2/16 - 15*x1/32 - 45*x2^3/64 + 75*x2^2/64 + 39*x2/64 - 9/64

  phi[10,1] = 135*x1^3/8 + 45*x1^2*x2/2 + 135*x1^2/8 + 45*x1*x2^2/8 + 75*x1*x2/4 - 15*x1/4 + 45*x2^2/8 - 15*x2/4 - 15/4
  phi[10,2] = 135*x1^2*x2/8 + 135*x1^2/8 + 45*x1*x2^2/2 + 165*x1*x2/4 + 75*x1/4 + 45*x2^3/8 + 165*x2^2/8 + 75*x2/4 + 15/4

  phi[11,1] = 45*x1^3/8 + 45*x1^2*x2/2 + 165*x1^2/8 + 135*x1*x2^2/8 + 165*x1*x2/4 + 75*x1/4 + 135*x2^2/8 + 75*x2/4 + 15/4
  phi[11,2] = 45*x1^2*x2/8 + 45*x1^2/8 + 45*x1*x2^2/2 + 75*x1*x2/4 - 15*x1/4 + 135*x2^3/8 + 135*x2^2/8 - 15*x2/4 - 15/4

  phi[12,1] = -135*x1^3/8 - 45*x1^2*x2/4 - 135*x1^2/8 - 15*x1*x2 + 15*x1/8 - 15*x2/4 + 15/8
  phi[12,2] = -135*x1^2*x2/8 - 135*x1^2/8 - 45*x1*x2^2/4 - 105*x1*x2/4 - 15*x1 - 15*x2^2/2 - 75*x2/8 - 15/8

  phi[13,1] = -45*x1^3/4 - 45*x1^2*x2/2 - 105*x1^2/4 - 30*x1*x2 - 75*x1/4 - 15*x2/2 - 15/4
  phi[13,2] = -45*x1^2*x2/4 - 45*x1^2/4 - 45*x1*x2^2/2 - 45*x1*x2/2 - 15*x2^2 - 45*x2/4 + 15/4

  phi[14,1] = -45*x1^2*x2/2 - 15*x1^2 - 45*x1*x2^2/4 - 45*x1*x2/2 - 45*x1/4 - 45*x2^2/4 + 15/4
  phi[14,2] = -45*x1*x2^2/2 - 30*x1*x2 - 15*x1/2 - 45*x2^3/4 - 105*x2^2/4 - 75*x2/4 - 15/4

  phi[15,1] = -45*x1^2*x2/4 - 15*x1^2/2 - 135*x1*x2^2/8 - 105*x1*x2/4 - 75*x1/8 - 135*x2^2/8 - 15*x2 - 15/8
  phi[15,2] = -45*x1*x2^2/4 - 15*x1*x2 - 15*x1/4 - 135*x2^3/8 - 135*x2^2/8 + 15*x2/8 + 15/8
       
  for i = 1 : DoF
    Divphi[i,1] = differentiate(phi[i,1],x1) + differentiate(phi[i,2],x2)
  end

  Glob = KernelAbstractions.zeros(backend,Int,DoF,Grid.NumFaces)
  GlobCPU = zeros(Int,DoF,Grid.NumFaces)
  NumG = Grid.NumEdgesI + Grid.NumEdgesB
  NumI = Grid.NumEdgesI
  for iF = 1 : Grid.NumFaces
    for i = 1 : length(Grid.Faces[iF].E)
      iE = Grid.Faces[iF].E[i]
      GlobCPU[i,iF] = Grid.Edges[iE].E
    end
  end
  copyto!(Glob,GlobCPU)
  M = spzeros(0,0)
  return RT2Struct{FT,
                  typeof(Glob)}( 
    Glob,
    DoF,
    Comp,
    phi,
    Divphi,                      
    NumG,
    NumI,
    Type,
    M,
      )
  end