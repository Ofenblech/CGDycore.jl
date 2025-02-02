import CGDycore:
  Examples, Parallels, Models, Grids, Outputs, Integration,  GPU, DyCore, FEMSei, FiniteVolumes
using MPI
using Base
using CUDA
using AMDGPU
using Metal
using KernelAbstractions
using StaticArrays
using ArgParse
using LinearAlgebra

# Model
parsed_args = DyCore.parse_commandline()
Problem = parsed_args["Problem"]
ProfRho = parsed_args["ProfRho"]
ProfTheta = parsed_args["ProfTheta"]
PertTh = parsed_args["PertTh"]
ProfVel = parsed_args["ProfVel"]
ProfVelGeo = parsed_args["ProfVelGeo"]
RhoVPos = parsed_args["RhoVPos"]
RhoCPos = parsed_args["RhoCPos"]
RhoIPos = parsed_args["RhoIPos"]
RhoRPos = parsed_args["RhoRPos"]
HorLimit = parsed_args["HorLimit"]
Upwind = parsed_args["Upwind"]
Damping = parsed_args["Damping"]
Relax = parsed_args["Relax"]
StrideDamp = parsed_args["StrideDamp"]
Geos = parsed_args["Geos"]
Coriolis = parsed_args["Coriolis"]
CoriolisType = parsed_args["CoriolisType"]
Buoyancy = parsed_args["Buoyancy"]
Equation = parsed_args["Equation"]
RefProfile = parsed_args["RefProfile"]
ProfpBGrd = parsed_args["ProfpBGrd"]
ProfRhoBGrd = parsed_args["ProfRhoBGrd"]
Microphysics = parsed_args["Microphysics"]
TypeMicrophysics = parsed_args["TypeMicrophysics"]
RelCloud = parsed_args["RelCloud"]
Rain = parsed_args["Rain"]
Source = parsed_args["Source"]
Forcing = parsed_args["Forcing"]
VerticalDiffusion = parsed_args["VerticalDiffusion"]
JacVerticalDiffusion = parsed_args["JacVerticalDiffusion"]
JacVerticalAdvection = parsed_args["JacVerticalAdvection"]
SurfaceFlux = parsed_args["SurfaceFlux"]
SurfaceFluxMom = parsed_args["SurfaceFluxMom"]
NumV = parsed_args["NumV"]
NumTr = parsed_args["NumTr"]
Curl = parsed_args["Curl"]
ModelType = parsed_args["ModelType"]
Thermo = parsed_args["Thermo"]
# Parallel
Decomp = parsed_args["Decomp"]
# Time integration
SimDays = parsed_args["SimDays"]
SimHours = parsed_args["SimHours"]
SimMinutes = parsed_args["SimMinutes"]
SimSeconds = parsed_args["SimSeconds"]
StartAverageDays = parsed_args["StartAverageDays"]
dtau = parsed_args["dtau"]
IntMethod = parsed_args["IntMethod"]
Table = parsed_args["Table"]
# Grid
nz = parsed_args["nz"]
nPanel = parsed_args["nPanel"]
H = parsed_args["H"]
Stretch = parsed_args["Stretch"]
StretchType = parsed_args["StretchType"]
TopoS = parsed_args["TopoS"]
GridType = parsed_args["GridType"]
RadEarth = parsed_args["RadEarth"]
# CG Element
OrdPoly = parsed_args["OrdPoly"]
# Viscosity
HyperVisc = parsed_args["HyperVisc"]
HyperDCurl = parsed_args["HyperDCurl"]
HyperDGrad = parsed_args["HyperDGrad"]
HyperDRhoDiv = parsed_args["HyperDRhoDiv"]
HyperDDiv = parsed_args["HyperDDiv"]
HyperDDivW = parsed_args["HyperDDivW"]
# Output
PrintDays = parsed_args["PrintDays"]
PrintHours = parsed_args["PrintHours"]
PrintMinutes = parsed_args["PrintMinutes"]
PrintSeconds = parsed_args["PrintSeconds"]
PrintStartTime = parsed_args["PrintStartTime"]
Flat = parsed_args["Flat"]

# Device
Device = parsed_args["Device"]
GPUType = parsed_args["GPUType"]
FloatTypeBackend = parsed_args["FloatTypeBackend"]
NumberThreadGPU = parsed_args["NumberThreadGPU"]

MPI.Init()
Flat = false #testen
Device = "CPU"
FloatTypeBackend = "Float64"

if Device == "CPU" 
  backend = CPU()
elseif Device == "GPU" 
  if GPUType == "CUDA"
    backend = CUDABackend()
    CUDA.allowscalar(true)
#   CUDA.device!(MPI.Comm_rank(MPI.COMM_WORLD))
  elseif GPUType == "AMD"
    backend = ROCBackend()
    AMDGPU.allowscalar(false)
  elseif GPUType == "Metal"
    backend = MetalBackend()
    Metal.allowscalar(true)
  end
else
  backend = CPU()
end

if FloatTypeBackend == "Float64"
  FTB = Float64
elseif FloatTypeBackend == "Float32"
  FTB = Float32
else
  @show "False FloatTypeBackend"
  stop
end

MPI.Init()
comm = MPI.COMM_WORLD
Proc = MPI.Comm_rank(comm) + 1
ProcNumber = MPI.Comm_size(comm)
ParallelCom = DyCore.ParallelComStruct()
ParallelCom.Proc = Proc
ParallelCom.ProcNumber  = ProcNumber

# Physical parameters
Phys = DyCore.PhysParameters{FTB}()

#ModelParameters
Model = DyCore.ModelStruct{FTB}()

RefineLevel = 5
nz = 1
nQuad = 3
nQuadM = 3 #2
nQuadS = 3 #3
Decomp = "EqualArea"
nLat = 0
nLon = 0
LatB = 0.0

#Quad
GridType = "CubedSphere"
#GridType = "TriangularSphere"
nPanel =  90
#GridType = "HealPix"
ns = 57

#Grid construction
RadEarth = Phys.RadEarth
Grid, Exchange = Grids.InitGridSphere(backend,FTB,OrdPoly,nz,nPanel,RefineLevel,ns,
  nLat,nLon,LatB,GridType,Decomp,RadEarth,Model,ParallelCom;ChangeOrient=3)

print("Which Problem do you want so solve? \n")
print("1 - GalewskiSphere\n\
       2 - HaurwitzSphere\n")

text = readline() 
a = parse(Int,text)
if  a == 1
    Problem = "GalewskiSphere"
    Param = Examples.Parameters(FTB,Problem)
    GridLengthMin,GridLengthMax = Grids.GridLength(Grid)
    cS = sqrt(Phys.Grav * Param.H0G)
    dtau = GridLengthMin / cS / sqrt(2) * .2
    EndTime = 24 * 3600 * 6# One day
    PrintTime = 3600
    nAdveVel = 10 #round(EndTime / dtau)
    dtau = EndTime / nAdveVel
    nprint = 1 #ceil(PrintTime/dtau)
    GridTypeOut = GridType*"NonLinShallowGal"
    @show GridLengthMin,GridLengthMax
    @show nAdveVel
    @show dtau
    @show nprint
elseif  a == 2
    Problem = "HaurwitzSphere"
    Param = Examples.Parameters(FTB,Problem)
    GridLengthMin,GridLengthMax = Grids.GridLength(Grid)
    cS = sqrt(Phys.Grav * Param.h0)
    dtau = GridLengthMin / cS / sqrt(2) * .3 
    EndTime = 24 * 3600 # One day
    PrintTime = 3600
    nAdveVel = 10 #round(EndTime / dtau)
    dtau = EndTime / nAdveVel
    nprint = 1 #ceil(PrintTime/dtau)
    GridTypeOut = GridType*"NonLinShallowHaurwitz"
    @show GridLengthMin,GridLengthMax
    @show nAdveVel
    @show dtau
    @show nprint
else 
    print("Error")
end
Examples.InitialProfile!(backend,FTB,Model,Problem,Param,Phys)

#Output
vtkSkeletonMesh = Outputs.vtkStruct{Float64}(backend,Grid,Grid.NumFaces,Flat)

#Finite elements
k = 0
DG = FEMSei.DGStruct{FTB}(backend,k,Grid.Type,Grid)
VecDG = FEMSei.VecDGStruct{FTB}(backend,k,Grid.Type,Grid)
RT = FEMSei.RTStruct{FTB}(backend,k,Grid.Type,Grid)

#massmatrix und LU-decomposition
DG.M = FEMSei.MassMatrix(backend,FTB,DG,Grid,nQuadM,FEMSei.Jacobi!)
DG.LUM = lu(DG.M)
VecDG.M = FEMSei.MassMatrix(backend,FTB,VecDG,Grid,nQuadM,FEMSei.Jacobi!)
VecDG.LUM = lu(VecDG.M)
RT.M = FEMSei.MassMatrix(backend,FTB,RT,Grid,nQuadM,FEMSei.Jacobi!)
RT.LUM = lu(RT.M)


#Runge-Kutta steps
time = 0.0

hPosS = 1
hPosE = DG.NumG
huPosS = DG.NumG + 1
huPosE = DG.NumG + RT.NumG

U = zeros(FTB,DG.NumG+RT.NumG)
@views Uh = U[hPosS:hPosE]  
@views Uhu = U[huPosS:huPosE]  
UNew = zeros(FTB,DG.NumG+RT.NumG)
@views UNewh = UNew[hPosS:hPosE]  
@views UNewhu = UNew[huPosS:huPosE]  
F = zeros(FTB,DG.NumG+RT.NumG)
@views Fh = F[hPosS:hPosE]  
@views Fhu = F[huPosS:huPosE]  
uRec = zeros(FTB,VecDG.NumG)
cName = ["h";"uS";"vS"]

FEMSei.InterpolateRT!(Uhu,RT,FEMSei.Jacobi!,Grid,Grid.Type,nQuad,Model.InitialProfile)
FEMSei.Project!(backend,FTB,Uh,DG,Grid,nQuad,FEMSei.Jacobi!,Model.InitialProfile)
# Output of the initial values
FileNumber=0
VelSp = zeros(Grid.NumFaces,2)
hout = zeros(Grid.NumFaces)
FEMSei.ConvertScalarVelocitySp!(backend,FTB,VelSp,Uhu,RT,Uh,DG,Grid,FEMSei.Jacobi!)
FEMSei.ConvertScalar!(backend,FTB,hout,Uh,DG,Grid,FEMSei.Jacobi!)

Outputs.vtkSkeleton!(vtkSkeletonMesh, GridTypeOut, Proc, ProcNumber, [hout VelSp] ,FileNumber,cName)
for i = 1 : nAdveVel
  @show i,(i-1)*dtau/3600 
  @. F = 0  
  # Tendency h
  FEMSei.DivRhs!(backend,FTB,Fh,DG,Uhu,RT,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  ldiv!(DG.LUM,Fh)
  # Tendency hu
  
  FEMSei.InterpolateScalarHDivVecDG!(backend,FTB,uRec,VecDG,Uh,DG,Uhu,RT,Grid,
    Grid.Type,nQuad,FEMSei.Jacobi!)
  
  FEMSei.DivMomentumVector!(backend,FTB,Fhu,RT,Uhu,RT,uRec,VecDG,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  FEMSei.CrossRhs!(backend,FTB,Fhu,RT,Uhu,RT,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  FEMSei.GradHeightSquared!(backend,FTB,Fhu,RT,Uh,DG,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  ldiv!(RT.LUM,Fhu)
  @. UNew = U + 1 / 3 * dtau * F
  @. F = 0  
  # Tendency h
  FEMSei.DivRhs!(backend,FTB,Fh,DG,UNewhu,RT,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  ldiv!(DG.LUM,Fh)
  # Tendency hu
  #FileNumber+=1
  FEMSei.InterpolateScalarHDivVecDG!(backend,FTB,uRec,VecDG,UNewh,DG,UNewhu,RT,Grid,
    Grid.Type,nQuad,FEMSei.Jacobi!)
  #FEMSei.ConvertVelocitySp!(backend,FTB,VelSp,uRec,VecDG,Grid,FEMSei.Jacobi!)
  #FEMSei.ConvertScalar!(backend,FTB,hout,UNewh,DG,Grid,FEMSei.Jacobi!)
  #Outputs.vtkSkeleton!(vtkSkeletonMesh, GridTypeOut, Proc, ProcNumber, [hout VelSp] ,FileNumber,cName)
  #stop


  FEMSei.DivMomentumVector!(backend,FTB,Fhu,RT,UNewhu,RT,uRec,VecDG,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  FEMSei.CrossRhs!(backend,FTB,Fhu,RT,UNewhu,RT,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  FEMSei.GradHeightSquared!(backend,FTB,Fhu,RT,UNewh,DG,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  ldiv!(RT.LUM,Fhu)
  @. UNew = U + 0.5 * dtau * F
  @. F = 0  
  # Tendency h
  FEMSei.DivRhs!(backend,FTB,Fh,DG,UNewhu,RT,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  ldiv!(DG.LUM,Fh)
  # Tendency hu
  FEMSei.InterpolateScalarHDivVecDG!(backend,FTB,uRec,VecDG,UNewh,DG,UNewhu,RT,Grid,
    Grid.Type,nQuad,FEMSei.Jacobi!)
  FEMSei.DivMomentumVector!(backend,FTB,Fhu,RT,UNewhu,RT,uRec,VecDG,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  FEMSei.CrossRhs!(backend,FTB,Fhu,RT,UNewhu,RT,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  FEMSei.GradHeightSquared!(backend,FTB,Fhu,RT,UNewh,DG,Grid,Grid.Type,nQuad,FEMSei.Jacobi!)
  ldiv!(RT.LUM,Fhu)
  @. U = U + dtau * F

    
  # Output
  if mod(i,nprint) == 0 
    global FileNumber += 1
    FEMSei.ConvertScalarVelocitySp!(backend,FTB,VelSp,Uhu,RT,Uh,DG,Grid,FEMSei.Jacobi!)
    FEMSei.ConvertScalar!(backend,FTB,hout,Uh,DG,Grid,FEMSei.Jacobi!)
    Outputs.vtkSkeleton!(vtkSkeletonMesh, GridTypeOut, Proc, ProcNumber, [hout VelSp] ,FileNumber,cName)
  end
end
@show "finished"

