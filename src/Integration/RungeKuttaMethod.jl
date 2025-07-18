mutable struct RungeKuttaMethod{FT<:AbstractFloat}
  nStage::Int
  Type::String
  ARKE::Array{FT, 2}
  bRKE::Array{FT, 1}
  cRKE::Array{FT, 1}
  ARKI::Array{FT, 2}
  bRKI::Array{FT, 1}
  gRKI::Array{FT, 1}
end

function RungeKuttaMethod{FT}() where FT<:AbstractFloat
  nStage=0
  Type=""
  ARKE=zeros(FT,0,0)
  bRKE=zeros(FT,0)
  cRKE=zeros(FT,0)
  ARKI=zeros(FT,0,0)
  bRKI=zeros(FT,0)
  gRKI=zeros(FT,0)
  return RungeKuttaMethod{FT}(
  nStage,
  Type,
  ARKE,
  bRKE,
  cRKE,
  ARKI,
  bRKI,
  gRKI,
  )
end  

function RungeKuttaMethod{FT}(Method) where FT<:AbstractFloat
  str = Method
if str == "ARK32"
    RK.nStage=3;
    RK.ARKE=zeros(FT,RK.nStage,RK.nStage);
    RK.bRKE=zeros(FT,1,RK.nStage);
    RK.ARKE[2,1]=2-sqrt(2);
    ARKE32=1/6*(3 + sqrt(2));
    RK.ARKE[3,1]=1-ARKE32;
    RK.ARKE[3,2]=ARKE32;
    RK.bRKE[1]=1/(2*sqrt(2));
    RK.bRKE[2]=1/(2*sqrt(2));
    RK.bRKE[3]=1-1/(sqrt(2));
    RK.ARKI=zeros(FT,RK.nStage,RK.nStage);
    RK.bRKI=zeros(FT,1,RK.nStage);
    RK.ARKI[2,1]=1-1/(sqrt(2));
    RK.ARKI[2,2]=1-1/(sqrt(2));
    RK.ARKI[3,1]=1/(2*sqrt(2));
    RK.ARKI[3,2]=1/(2*sqrt(2));
    RK.ARKI[3,3]=1-1/(sqrt(2));
    RK.bRKI[1]=1/(2*sqrt(2));
    RK.bRKI[2]=1/(2*sqrt(2));
    RK.bRKI[3]=1-1/(sqrt(2));
    RK.gRKI=1-1/(sqrt(2));
elseif str == "Trap2(2,3,2)"
    #Trap2(2,3,2)
    RK.nStage=4;
    RK.ARKE=zeros(FT,RK.nStage,RK.nStage);
    RK.bRKE=zeros(FT,1,RK.nStage);
    RK.ARKE[2,1]=1;
    RK.ARKE[3,1]=1/2;
    RK.ARKE[3,2]=1/2;
    RK.ARKE[4,1]=1/2;
    RK.ARKE[4,3]=1/2;
    RK.bRKE[1]=1/2;
    RK.bRKE[2]=0;
    RK.bRKE[3]=1/2;
    RK.bRKE[4]=0;
elseif str == "RK1"
    nStage=1
    Type=""
    ARKE=zeros(FT,nStage,nStage);
    bRKE=[1];
    cRKE=[0];
    ARKI=zeros(FT,0,0)
    bRKI=zeros(FT,0)
    gRKI=zeros(FT,0)
elseif str == "RK1I"
    RK.nStage=1;
    RK.ARKE=zeros(FT,RK.nStage,RK.nStage);
    RK.ARKE[1,1]=1;
    RK.bRKE=zeros(FT,1,RK.nStage);
    RK.bRKE[1]=1;
elseif str == "RK4"
    nStage=4;
    Type=""
    ARKE=zeros(FT,nStage,nStage);
    ARKE[2,1]=1/2;
    ARKE[3,2]=1/2;
    ARKE[4,3]=1;
    bRKE=[1/6,1/3,1/3,1/6];
    cRKE=[0,1/2,1/2,1];
    ARKI=zeros(FT,0,0)
    bRKI=zeros(FT,0)
    gRKI=zeros(FT,0)
elseif str == "SSP3"
    nStage=3;
    Type=""
    ARKE=zeros(FT,nStage,nStage);
    ARKE[2,1] = 1.0
    ARKE[3,1] = 0.25
    ARKE[3,2] = 0.25
    bRKE = [1/6,1/6,1/3]
    cRKE = [0,1,1/2]
    ARKI=zeros(FT,0,0)
    bRKI=zeros(FT,0)
    gRKI=zeros(FT,0)
elseif str == "Kinnmark"
    nStage=5;
    Type="LowStorage"
    ARKE=zeros(FT,nStage,nStage);
    ARKE[2,1]=1/5;
    ARKE[3,2]=1/5;
    ARKE[4,3]=1/3;
    ARKE[5,4]=1/2;
    bRKE=[0,0,0,0,1];
    ARKI=zeros(FT,0,0)
    bRKI=zeros(FT,0)
    gRKI=zeros(FT,0)
elseif str == "RK3"
    nStage=3;
    Type=""
    ARKE=zeros(FT,nStage,nStage);
    ARKE[2,1]=1/3;
    ARKE[3,2]=1/2;
    bRKE = [0,0,1]
    cRKE=[0,1/3,1/2];
    ARKI=zeros(FT,0,0)
    bRKI=zeros(FT,0)
    gRKI=zeros(FT,0)
elseif str == "DBM453"
    RK.nStage=5;
    RK.ARKE=zeros(FT,RK.nStage,RK.nStage);
    RK.bRKE=zeros(FT,1,RK.nStage);
    RK.ARKE[2,1]=0.10306208811591838;
    RK.ARKE[3,1]=-0.94124866143519894;
    RK.ARKE[3,2]=1.6626399742527356;
    RK.ARKE[4,1]=-1.3670975201437765;
    RK.ARKE[4,2]=1.3815852911016873;
    RK.ARKE[4,3]=1.2673234025619065;
    RK.ARKE[5,1]=-0.81287582068772448;
    RK.ARKE[5,2]=0.81223739060505738;
    RK.ARKE[5,3]=0.90644429603699305;
    RK.ARKE[5,4]=0.094194134045674111;

    RK.bRKE[1]=0.87795339639076672;
    RK.bRKE[2]=-0.72692641526151549;
    RK.bRKE[3]=0.7520413715737272;
    RK.bRKE[4]=-0.22898029400415090;
    RK.bRKE[5]=0.32591194130117247;

    RK.gRKI=0.32591194130117247;
    RK.ARKI=zeros(FT,RK.nStage,RK.nStage);
    RK.bRKI=zeros(FT,1,RK.nStage);
    RK.ARKI[2,1]=-0.22284985318525410;
    RK.ARKI[2,2]=RK.gRKI;
    RK.ARKI[3,1]=-0.46801347074080545;
    RK.ARKI[3,2]=0.86349284225716961;
    RK.ARKI[3,3]=RK.gRKI;
    RK.ARKI[4,1]=-0.46509906651927421;
    RK.ARKI[4,2]=0.81063103116959553;
    RK.ARKI[4,3]=0.61036726756832357;
    RK.ARKI[4,4]=RK.gRKI;
    RK.ARKI[5,1]=0.87795339639076675;
    RK.ARKI[5,2]=-0.72692641526151547;
    RK.ARKI[5,3]=0.75204137157372720;
    RK.ARKI[5,4]=-0.22898029400415088;
    RK.ARKI[5,5]=RK.gRKI;
    RK.bRKI=RK.bRKE;
end
  return RungeKuttaMethod{FT}(
  nStage,
  Type,
  ARKE,
  bRKE,
  cRKE,
  ARKI,
  bRKI,
  gRKI,
  )
end
