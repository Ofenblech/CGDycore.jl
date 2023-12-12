using NCDatasets
using StructArrays

mutable struct TilesRawGrid_T
  altitude::Array{Union{Missing, Int32}, 2}
  lon::Array{Float32, 1}
  lat::Array{Float32, 1}
  lon_max::Float64
  lon_min::Float64
  lat_max::Float64
  lat_min::Float64
  start_lon::Float64
  end_lon::Float64
  start_lat::Float64
  end_lat::Float64
  dlon::Float64
  dlat::Float64
  nlon::Int
  nlat::Int
end

function TilesRawGrid_T()
  altitude = zeros(Int32,0,0)
  lon = zeros(Float32,0)
  lat = zeros(Float32,0)
  lon_max = 0.0
  lon_min = 0.0
  lat_max = 0.0
  lat_min = 0.0
  start_lon = 0.0
  end_lon = 0.0
  start_lat = 0.0
  end_lat = 0.0
  dlon = 0.0
  dlat = 0.0
  nlon = 0
  nlat = 0
  return TilesRawGrid_T(
    altitude,
    lon,
    lat,
    lon_max,
    lon_min,
    lat_max,
    lat_min,
    start_lon,
    end_lon,
    start_lat,
    end_lat,
    dlon,
    dlat,
    nlon,
    nlat)
end  

function TopoData()
  nlon = 200
  nlat = 100
  dlon = 360 / nlon
  dlat = 180 / nlat
  lon = collect(0 : dlon : 360)
  lat = collect(90 : dlat : -90)
  nlon = nlon + 1
  nlat = nlat + 1
  nlon1 = 1
  nlon2 = nlon
  nlat1 = 51-0
  nlat2 = 51+0
  zlevels = zeros(Float64,nlon,nlat)
  @inbounds for ilat = nlat1 : nlat2
    zlevels[nlon1:nlon2,ilat] .= 200.0 
  end  
  return (lon, lat, zlevels)
end
function TopoDataETOPO(MinLonL,MaxLonL,MinLonR,MaxLonR,MinLat,MaxLat)
  # Load ETOPO1 ice-sheet surface data
  # Ocean values are considered 0
  ds = NCDataset("ETOPO1_Ice_g_gdal.grd")
  # Unpack information
  x_range = ds["x_range"][:]
  y_range = ds["y_range"][:]
  z_range = ds["z_range"][:]
  spacing = ds["spacing"][:]
  dimension = ds["dimension"][:]
  elevation = ds["z"][:]
  lon = collect(x_range[1]:spacing[1]:x_range[2])
  lat = collect(y_range[1]:spacing[2]:y_range[2])
  nlon = dimension[1]
  nlat = dimension[2]
  dLon = 360.0 / nlon
  dLat = 180.0 / nlat
  ilonLS = max(floor(Int,(MinLonL+180.)/dLon),1)
  ilonLE = min(ceil(Int,(MaxLonL+180.)/dLon),nlon)
  ilonRS = max(floor(Int,(MinLonR+180.)/dLon),1)
  ilonRE = min(ceil(Int,(MaxLonR+180.)/dLon),nlon)
  ilatS = max(floor(Int,(MinLat+90.)/dLat),1)
  ilatE = min(ceil(Int,(MaxLat+90.)/dLat),nlat)
  @show MinLonL,MaxLonL
  @show MinLonR,MaxLonR
  @show ilonLS,ilonLE
  @show ilonRS,ilonRE
  @show ilatS,ilatE
  temp = max.(reshape(elevation, (nlon, nlat)), 0.0)
  zlevels = zeros(Float64,nlon,nlat)
  @inbounds for i = 1 : nlat
     @.  zlevels[:,i] = temp[:,nlat+1-i]
  end   
  return (lon[ilonLS:ilonLE], lon[ilonRS:ilonRE], lat[ilatS:ilatE], 
    zlevels[ilonLS:ilonLE,ilatS:ilatE], zlevels[ilonRS:ilonRE,ilatS:ilatE])
end  

function TopoDataGLOBE()
  deg2rad = pi / 180.0
  RadEarth = 6.37122e+6
  ntiles_column = 4
  ntiles_row = 4
  ntiles = ntiles_column * ntiles_row
  list=["GLOBE_A10.nc",
        "GLOBE_B10.nc",
        "GLOBE_C10.nc",
        "GLOBE_D10.nc",
        "GLOBE_E10.nc",
        "GLOBE_F10.nc",
        "GLOBE_G10.nc",
        "GLOBE_H10.nc",
        "GLOBE_I10.nc",
        "GLOBE_J10.nc",
        "GLOBE_K10.nc",
        "GLOBE_L10.nc",
        "GLOBE_M10.nc",
        "GLOBE_N10.nc",
        "GLOBE_O10.nc",
        "GLOBE_P10.nc"]

  TilesRawGrid = map(1:ntiles) do i
    TilesRawGrid_T()
  end
  i = 1
  nlon_tot = 0
  nlat_tot = 0
  @inbounds for file in list
    ds = NCDataset("Topo/"*file)  
    nlon = ds.dim["lon"]
    nlat = ds.dim["lat"]
    nlon_tot += nlon
    nlat_tot += nlat
    close(ds)
#   TilesRawGrid[i].altitude = data["altitude"][:,:]
#   TilesRawGrid[i].altitude.attrib["_FillValue"] = 0
#   TilesRawGrid[i].lon = data["lon"][:]
#   TilesRawGrid[i].lat = data["lat"][:]
#   TilesRawGrid[i].lon_min = minimum(TilesRawGrid[i].lon)
#   TilesRawGrid[i].lon_max = maximum(TilesRawGrid[i].lon)
#   TilesRawGrid[i].lat_min = minimum(TilesRawGrid[i].lat)
#   TilesRawGrid[i].lat_max = maximum(TilesRawGrid[i].lat)
#   TilesRawGrid[i].nlon = size(TilesRawGrid[i].lon,1)
#   TilesRawGrid[i].nlat = size(TilesRawGrid[i].lat,1)
#   @show TilesRawGrid[i].nlon,TilesRawGrid[i].nlat
#   @show TilesRawGrid[i].lon_min,TilesRawGrid[i].lon_max
#   @show TilesRawGrid[i].lat_min,TilesRawGrid[i].lat_max
#   nlon_tot += TilesRawGrid[i].nlon
#   nlat_tot += TilesRawGrid[i].nlat
#   TilesRawGrid[i].dlon = (TilesRawGrid[i].lon_max - TilesRawGrid[i].lon_min) / TilesRawGrid[i].nlon
#   TilesRawGrid[i].dlat = (TilesRawGrid[i].lat_max - TilesRawGrid[i].lat_min) / TilesRawGrid[i].nlat
#   # latitude from north to south, negative increment
#   TilesRawGrid[i].start_lon  += 0.5 * TilesRawGrid[i].dlon
#   TilesRawGrid[i].end_lon  -= 0.5 * TilesRawGrid[i].dlon
#   # latitude from north to south, note the negative increment!
#   TilesRawGrid[i].start_lat  += 0.5 * TilesRawGrid[i].dlat
#   # latitude from north to south, note the negative increment!
#   TilesRawGrid[i].end_lat -= 0.5 * TilesRawGrid[i].dlat
#   @show minimum(TilesRawGrid[i].lon),maximum(TilesRawGrid[i].lon)
#   @show minimum(TilesRawGrid[i].lat),maximum(TilesRawGrid[i].lat)
#   @show size(TilesRawGrid[i].lon),size(TilesRawGrid[i].lat)
#   @show size(TilesRawGrid[i].altitude)
    println("")
#   i += 1
  end   
  @show nlon_tot
  @show nlat_tot
# Altitude = zeros(Int32,nlon_tot,nlat_tot)
    ds = NCDataset("Topo/"*list[13])
    a = coalesce.(ds["altitude"],Int32(0))
    nlon = ds.dim["lon"]
    nlat = ds.dim["lat"]
    nlonA = 1
    nlonE = nlon
    nlatA = 1
    nlatE = nlat
    @show maximum(a),minimum(a)
    close(ds)
  stop
  nlonA = 0 
  nlon = TilesRawGrid[13].nlon
  nlatA = 0 
  nlat = TilesRawGrid[13].nlat
  @inbounds for i = 1 : nlon
    ilon = i + nlonA  
    @inbounds for j = 1 : nlat  
      jlat = j + nlatA  
      @show i,j,TilesRawGrid[13].altitude[i,j]
      Altitude[ilon,jlat] = Int(TilesRawGrid[13].altitude[i,j])
    end
  end  
end

function Orography(backend,FT,CG,Global,TopoProfile)
  Grid = Global.Grid
  Faces = Grid.Faces
  Proc = Global.ParallelCom.Proc
  OrdPoly = CG.OrdPoly
  NF = Grid.NumFaces
  OP = OrdPoly + 1
  DoF = CG.DoF
  HeightCGCPU = zeros(Float64,OP,OP,NF)
  xe = zeros(OrdPoly+1)
  xe[1] = -1.0
  @inbounds for i = 2 : OrdPoly
    xe[i] = CG.xe[i-1] + 2.0/OrdPoly
  end
  xe[OrdPoly+1] = 1.0
  X = zeros(3)
  for iF = 1 : NF
    for j = 1 : OP  
      for i = 1 : OP
        X[1] = 0.25 * ((1 - xe[i]) * (1 - xe[j]) * Faces[iF].P[1].x + 
          (1 + xe[i]) * (1 - xe[j]) * Faces[iF].P[2].x + 
          (1 + xe[i]) * (1 + xe[j]) * Faces[iF].P[3].x + 
          (1 - xe[i]) * (1 + xe[j]) * Faces[iF].P[4].x)
        X[2] = 0.25* ((1 - xe[i]) * (1 - xe[j]) * Faces[iF].P[1].y + 
          (1 + xe[i]) * (1 - xe[j]) * Faces[iF].P[2].y + 
          (1 + xe[i]) * (1 + xe[j]) * Faces[iF].P[3].y + 
          (1 - xe[i]) * (1 + xe[j]) * Faces[iF].P[4].y)  
        X[3] = 0.25* ((1 - xe[i]) * (1 - xe[j]) * Faces[iF].P[1].z + 
          (1 + xe[i]) * (1 - xe[j]) * Faces[iF].P[2].z + 
          (1 + xe[i]) * (1 + xe[j]) * Faces[iF].P[3].z + 
          (1 - xe[i]) * (1 + xe[j]) * Faces[iF].P[4].z)  
        HeightCGCPU[i,j,iF] = TopoProfile(X)
      end  
    end  
    @views ChangeBasisHeight!(HeightCGCPU[:,:,iF],HeightCGCPU[:,:,iF],CG)
  end  
  HeightCG = KernelAbstractions.zeros(backend,FT,size(HeightCGCPU))
  copyto!(HeightCG,HeightCGCPU)

  return HeightCG
end

function Orography(CG,Global)
  Grid = Global.Grid
  Proc = Global.ParallelCom.Proc
  OrdPoly = CG.OrdPoly
  (MinLonL,MaxLonL,MinLonR,MaxLonR,MinLat,MaxLat) = BoundingBox(Grid)
  RadEarth = Grid.Rad
  NF = Grid.NumFaces
  OP = OrdPoly + 1
  HeightCG = zeros(Float64,OP,OP,NF)
  (lonL, lonR, lat, zLevelL, zLevelR) = TopoDataETOPO(MinLonL,MaxLonL,MinLonR,MaxLonR,MinLat,MaxLat)
# (lon, lat, zLevel) = CGDycore.TopoData()
  start_Face = 1
  (Glob,NumG) = NumberingFemCG(Grid,OrdPoly);
  Height = zeros(Float64,NumG)
  NumHeight = zeros(Float64,NumG)
# (w,xw) = GaussLobattoQuad(OrdPoly)
  xe = zeros(OrdPoly+1)
  xe[1] = -1.0
  @inbounds for i = 2 : OrdPoly
    xe[i] = CG.xe[i-1] + 2.0/OrdPoly
  end
  xe[OrdPoly+1] = 1.0

# LenLat = length(lat)
# LenLon = length(lon)
# dLon = 360.0 / LenLon
# dLat = 180.0 / LenLat
# ilonLS = max(floor(Int,(MinLonL+180.)/dLon),1)
# ilonLE = min(ceil(Int,(MaxLonL+180.)/dLon),LenLon)
# ilonRS = max(floor(Int,(MinLonR+180.)/dLon),1)
# ilonRE = min(ceil(Int,(MaxLonR+180.)/dLon),LenLon)
# ilatS = max(floor(Int,(MinLat+90.)/dLat),1)
# ilatE = min(ceil(Int,(MaxLat+90.)/dLat),LenLat)
  @inbounds for ilat = 1 : length(lat)
    @inbounds for ilon = 1 : length(lonL)
      P = Point(sphereDeg2cart(lonL[ilon],lat[ilat],RadEarth))
      (Face_id, iPosFace_id, jPosFace_id) = walk_to_nc(P,start_Face,xe,TransSphereS,RadEarth,Grid)
      start_Face = Face_id
      Inside = InsideFace(P,Grid.Faces[start_Face],Grid)
      if Inside
        iG = Glob[iPosFace_id,jPosFace_id,Face_id]
        Height[iG] += zLevelL[ilon,ilat]
        NumHeight[iG] += 1
      end  
    end
    @inbounds for ilon = 1 : length(lonR)
      P = Point(sphereDeg2cart(lonR[ilon],lat[ilat],RadEarth))
      (Face_id, iPosFace_id, jPosFace_id) = walk_to_nc(P,start_Face,xe,TransSphereS,RadEarth,Grid)
      start_Face = Face_id
      Inside = InsideFace(P,Grid.Faces[start_Face],Grid)
      if Inside
        iG = Glob[iPosFace_id,jPosFace_id,Face_id]
        Height[iG] += zLevelR[ilon,ilat]
        NumHeight[iG] += 1
      end  
    end
  end
  ExchangeData!(Height,Global.Exchange)
  ExchangeData!(NumHeight,Global.Exchange)
  @. Height /= (NumHeight + 1.e-14)
  @inbounds for iF = 1:NF
    @inbounds for jP=1:OP
      @inbounds for iP=1:OP
        ind = Glob[iP,jP,iF]
        HeightCG[iP,jP,iF] = Height[ind]
      end
    end
  end
  @inbounds for iF = 1:NF
    @views ChangeBasisHeight!(HeightCG[:,:,iF],HeightCG[:,:,iF],CG)
  end
  SmoothFac=1.e9
# SmoothFac=1.e15
  FHeightCG = similar(HeightCG)
  @inbounds for i=1:30
    TopographySmoothing1!(FHeightCG,HeightCG,CG,Global,SmoothFac)
    @. HeightCG += FHeightCG
    @. HeightCG = max(HeightCG,0.0)
  end
  @show maximum(HeightCG)
  @show minimum(HeightCG)
  return HeightCG
end

function BoundingBoxFace(Face,Grid)
  MinLon = 180.0
  MaxLon = -180.0
  MinLat = 90.0
  MaxLat = -90.0
  @inbounds for iN in Face.N
    P = Grid.Nodes[iN].P
    (lon, lat) = cart2sphereDeg(P.x,P.y,P.z)
    MinLon = min(MinLon, lon)
    MaxLon = max(MaxLon, lon)
    MinLat = min(MinLat, lat)
    MaxLat = max(MaxLat, lat)
  end
  return (MinLon,MaxLon,MinLat,MaxLat)
end

function BoundingBox(Grid)
  MinLonL = 0.0 
  MaxLonL = -180.0
  MinLonR = 180.0  
  MaxLonR = 0.0
  MinLat = 90.0
  MaxLat = -90.0
  @inbounds for i = 1 : Grid.NumFaces
    (MinLonF,MaxLonF,MinLatF,MaxLatF)= BoundingBoxFace(Grid.Faces[i],Grid) 
    if MinLonF >= 0.0
      MinLonR = min(MinLonR, MinLonF)
      MaxLonR = max(MaxLonR, MaxLonF)
    elseif MaxLonF  < 0.0
      MinLonL = min(MinLonL, MinLonF)
      MaxLonL = max(MaxLonL, MaxLonF)
    else
      if abs(MaxLonF-MinLonF)>90.0   
        MinLonL = min(MinLonL, -180.0)
        MaxLonL = max(MaxLonL, MinLonF)
        MinLonR = min(MinLonR, MaxLonF)
        MaxLonR = max(MaxLonR, 180.0)
      else
        MinLonL = min(MinLonL, MinLonF)
        MaxLonL = max(MaxLonL, 0.0)
        MinLonR = min(MinLonR, 0.0)
        MaxLonR = max(MaxLonR, MaxLonF)
      end
    end
    MinLat = min(MinLat, MinLatF)
    MaxLat = max(MaxLat, MaxLatF)
  end
  return (MinLonL,MaxLonL,MinLonR,MaxLonR,MinLat,MaxLat)
end

function SphereGrid(Height,Grid,xE)
  NumFaces = Grid.NumFaces
  nZ = Grid.nZ
  ne = size(xE,1)
  XE = zeros(NumFaces,nZ+1,nx,nx,3)
  @inbounds for iF = 1 : NumFaces
    Faces = Grid.Faces(iF)  
    @inbounds for i = 1 : ne
      ksi = xe(i)  
      for j = 1 : ne
        eta = xe(j)  
        XE[iF,1,i,j,:] = (1.0 - ksi) * (1.0 - eta) * F.P[1] +
                         (1.0 + ksi) * (1.0 - eta) * F.P[2] +
                         (1.0 + ksi) * (1.0 + eta) * F.P[3] +
                         (1.0 - ksi) * (1.0 + eta) * F.P[4]
        XE[iF,1,i,j,:] = RadEarth * XE[iF,1,i,j,:] / norm(XE[iF,1,i,j,:])                  
        XE[iF,1,i,j,3] = XE[iF,1,i,j,3] + Height[i,j,iF]
      end
    end
  end
end  

function ChangeBasisHeight!(XOut,XIn,CG)

  nxOut = size(XOut,1)
  nyOut = size(XOut,2)
  nxIn = size(XIn,1)
  nyIn = size(XIn,2)

  Buf1 = zeros(nxOut,nyIn)

  @inbounds for jIn = 1 : nyIn
    @inbounds for iIn = 1 : nxIn
      @inbounds for iOut = 1 : nxOut
        Buf1[iOut,jIn] = Buf1[iOut,jIn] +
          CG.IntXE2F[iOut,iIn] * XIn[iIn,jIn]
      end
    end
  end
  @. XOut = 0.0
  @inbounds for jIn = 1 : nyIn
    @inbounds for jOut = 1 : nyOut
      @inbounds for iOut = 1 : nxOut
        XOut[iOut,jOut] = XOut[iOut,jOut] +
          CG.IntXE2F[jOut,jIn] * Buf1[iOut,jIn]
      end
    end
  end
end