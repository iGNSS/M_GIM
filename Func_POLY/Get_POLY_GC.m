function [G_R, G_S, C_R, C_S, IONC, m0, NN] = Get_POLY_GC(fig,doy ,Sites_Info,sate,SDCB_REF,K,M,lat0,lon0,PG,PC,sate_mark)
%%  estimate satellite and receiver DCBs, ionospheric parameters, et al.
%%  produced from 'Get_MDCB.m' in M_DCB 
% INPUT:
%     fig: group number of products
%     doy: year and doy of year
%     Sites_Info: name and coordinate information of the stations
%     sate: precise coordinates of the satellites
%     SDCB_REF: reference satellite DCBs
%     K,M: order and degree of polynomial model
%     lat0,lon0: latitude and longitude of geometric center
%     PG,PC: weight of different system observations
% OUTPUT:
%     G_R, G_S, C_R, C_S: estimated receiver and satellite DCBs
%     IONC: ionospheric parameters
%     m0: standard deviation
%     NN: covariance matrices
%% written by Jin R et al., 2012/5/26, doi:10.1007/s10291-012-0279-3
%% modified by Zhou C. et al., 2021/12/14
%% --------------------------------------------------------------------------
Coor=Sites_Info.coor;
stations=Sites_Info.name;
doys=Sites_Info.doy;
%% check the gps data
gpsx=sate.gpsx;gpsy=sate.gpsy;gpsz=sate.gpsz;
path_G=['P4/regional/GPS/' doy];
list_gps=dir([path_G '/*.mat']);
G_n_r=length(list_gps);%the number of receivers
%--check the number of each satellite's observations 
gpsnum=sum(sate_mark.gps);
G_PRN=linspace(0,0,gpsnum);
G_S=linspace(0,0,gpsnum);
for i=1:G_n_r
    load([path_G '/' list_gps(i).name],'-mat');
    for j=1:gpsnum
        for k=1:2880
            if GPSP4(k,j)~=0
                G_PRN(j)=G_PRN(j)+1;
            end
        end
    end
    clear GPSP4;
end
gps_d_sat=find(G_PRN==0);
if isempty(gps_d_sat)
    G_n_s=gpsnum;
else
    G_n_s=gpsnum-length(gps_d_sat);%the number of satellites
    disp(['doy ', doy ,' GPS PRN ',num2str(gps_d_sat) ,' have no observations.']);
    for k=length(gps_d_sat):-1:1
        gpsx(:,gps_d_sat(k))=[];gpsy(:,gps_d_sat(k))=[];gpsz(:,gps_d_sat(k))=[];
    end
end

if G_n_s==gpsnum
    G_Wx=0;
else
    %Satellites DCB values must be exsist in related ionox files
    index= SDCB_REF.doy==str2double(doy); 
    G_Wx=-sum(SDCB_REF.gps(index,gps_d_sat));
    G_S(gps_d_sat)=SDCB_REF.gps(index,gps_d_sat);
end

%% check the bds data
bdsx=sate.bdsx;bdsy=sate.bdsy;bdsz=sate.bdsz;
path_C=['P4/regional/BDS/' doy];
list_bds=dir([path_C '/*.mat']);
C_n_r=length(list_bds);%the number of receivers
%--check the number of each satellite's observations 
bdsnum=sum(sate_mark.bds);
C_PRN=linspace(0,0,bdsnum);
C_S=linspace(0,0,bdsnum);
for i=1:C_n_r
    load([path_C '/' list_bds(i).name],'-mat');
    for j=1:bdsnum
        for k=1:2880
            if BDSP4(k,j)~=0
                C_PRN(j)=C_PRN(j)+1;
            end
        end
    end
    clear BDSP4;
end
bds_d_sat=find(C_PRN==0);
if isempty(bds_d_sat)
    C_n_s=bdsnum;
else
    C_n_s=bdsnum-length(bds_d_sat);%the number of satellites
    disp(['doy ', doy ,' BDS PRN ',num2str(bds_d_sat) ,' have no observations.']);
    for k=length(bds_d_sat):-1:1
        bdsx(:,bds_d_sat(k))=[];bdsy(:,bds_d_sat(k))=[];bdsz(:,bds_d_sat(k))=[];
    end
end
if C_n_s==bdsnum
    C_Wx=0;
else
    %Satellites DCB values must be exsist in related ionox files
    index= SDCB_REF.doy==str2double(doy); 
    C_Wx=-sum(SDCB_REF.bds(index,bds_d_sat));
    C_S(bds_d_sat)=SDCB_REF.bds(index,bds_d_sat);
end

%% --chose the order of spheric harmonic function
%order=str2double(input('Please input the order of spheric harmonic function (4 order is recommended):','s'));
%--LS estimate
n_m=((K+1)*(M+1))*fig;
num=n_m+G_n_s+G_n_r+C_n_s+C_n_r;
N=zeros(num,num);
U=zeros(num,1);
L=0; sizel=0;
C_GPS=linspace(0,0,num);
C_BDS=linspace(0,0,num);
C_GPS(G_n_r+1:G_n_r+G_n_s)=ones(1,G_n_s);
C_BDS(G_n_r+G_n_s+C_n_r+1:G_n_r+G_n_s+C_n_r+C_n_s)=ones(1,C_n_s);

for i=1:G_n_r
    load([path_G '/' list_gps(i).name],'-mat');
    if ~isempty(gps_d_sat)
        for k=length(gps_d_sat):-1:1
            GPSP4(:,gps_d_sat(k))=[];
        end
    end
    site=list_gps(i).name(1:4);
    indices=doys==str2double(doy);
    index=find(strcmpi(site,stations(indices)), 1);
    sx=Coor(index,1);
    sy=Coor(index,2);
    sz=Coor(index,3);
    [sN,sl]=Get_GPSMatrix(fig,GPSP4,gpsx,gpsy,gpsz,sx,sy,sz,G_n_r,C_n_r,G_n_s,C_n_s,i,K,M,lat0,lon0);
    N=N+sN'*sN*PG;
    U=U+sN'*sl*PG;
    %--RMS
    sizel=sizel+length(sl);
    L=L+sl'*sl*PG;
    %-----------
    clear GPSP4;
    disp(['1.----- [ ',num2str(i),' / ',num2str(G_n_r),' ] ',num2str(i/G_n_r*100),'% GPS data has constructed !']);
end

for i=1:C_n_r
    load([path_C '/' list_bds(i).name],'-mat');
    if ~isempty(bds_d_sat)
        for k=length(bds_d_sat):-1:1
            BDSP4(:,bds_d_sat(k))=[];
        end
    end
    site=list_bds(i).name(1:4);
    indices=doys==str2double(doy);
    index=find(strcmpi(site,stations(indices)), 1);
    sx=Coor(index,1);
    sy=Coor(index,2);
    sz=Coor(index,3);
    [sN,sl]=Get_BDSMatrix(fig,BDSP4,bdsx,bdsy,bdsz,sx,sy,sz,G_n_r,C_n_r,G_n_s,C_n_s,i,K,M,lat0,lon0);
    N=N+sN'*sN*PC;
    U=U+sN'*sl*PC;
    %--RMS
    sizel=sizel+length(sl);
    L=L+sl'*sl*PC;
    %-----------
    clear BDSP4;
    disp(['4.----- [ ',num2str(i),' / ',num2str(C_n_r),' ] ',num2str(i/C_n_r*100),'% BDS data has constructed !']);
end

N=N+C_GPS'*C_GPS+C_BDS'*C_BDS;
U=U+C_GPS'*G_Wx+C_BDS'*C_Wx;
L=L+G_Wx'*G_Wx+C_Wx'*C_Wx;
R=pinv(N)*U;
G_R=R(1:G_n_r)*10^9/299792458;
temp_gps=linspace(1,gpsnum,gpsnum);
temp_gps(gps_d_sat)=[];
G_S(temp_gps)=R(G_n_r+1:G_n_r+G_n_s)*10^9/299792458;

C_R=R(G_n_r+G_n_s+1:G_n_r+G_n_s+C_n_r)*10^9/299792458;
temp_bds=linspace(1,bdsnum,bdsnum);
temp_bds(bds_d_sat)=[];
C_S(temp_bds)=R(G_n_r+G_n_s+C_n_r+1:G_n_r+G_n_s+C_n_r+C_n_s)*10^9/299792458;

IONC=R(G_n_r+G_n_s+C_n_r+C_n_s+1:end);
%--RMS
V=L-R'*U;
f=sizel-num;
m0=sqrt(V/f);
NN=N(G_n_r+G_n_s+C_n_r+C_n_s+1:end,G_n_r+G_n_s+C_n_r+C_n_s+1:end);
%------
end

%% ------------------------------sub_function--------------------------------
function [MC,l]=Get_GPSMatrix(fig,GPSP4,x,y,z,sx,sy,sz,gps_n_r,bds_n_r,gps_n_s,bds_n_s,ith,K,M,lat0,lon0)
MC=[];l=[];
num=(K+1)*(M+1);
[sb,sl]=XYZtoBLH(sx,sy,sz);
figt=2880/fig;
for i=1:fig
    for j=1:gps_n_s                %-----------------------j is satellite number
        parfor k=figt*i-(figt-1):figt*i %-------------------------k is epoch number
            if GPSP4(k,j)==0
                continue;
            end
            M_col=linspace(0,0,num*fig+gps_n_s+gps_n_r+bds_n_s+bds_n_r);
            [E,A]=Get_EA(sx,sy,sz,x(k,j)*1000,y(k,j)*1000,z(k,j)*1000); %----sx,sy,sz station coordinate ; x,y,z satellite coordinate
            IPPz=asin(6371000*sin(pi/2-E)/(6371000+450000));%-----SLM 
            t_r=30*(k-1)*pi/43200;
            [b,s]=Get_IPP(E,A,sb,sl,IPPz,t_r);%
            M_col(ith)=(-9.52437)*cos(IPPz);   %-----station dcb coefficient
            M_col(gps_n_r+j)=(-9.52437)*cos(IPPz); %---satallite dcb coefficient
            st=num*(i-1)+gps_n_r+gps_n_s+bds_n_r+bds_n_s+1;
            ed=num*i+gps_n_r+gps_n_s+bds_n_r+bds_n_s;
            M_col(st:ed)=Get_POLY(b,s,K,M,lat0,lon0);
            M_scol=sparse(M_col);
            MC=[MC;M_scol]; 
            l=[l;GPSP4(k,j)*(-9.52437)*cos(IPPz)];
        end
    end
end
end

%% ------------------------------sub_function--------------------------------
function [MC,l]=Get_BDSMatrix(fig,BDSP4,x,y,z,sx,sy,sz,gps_n_r,bds_n_r,gps_n_s,bds_n_s,ith,K,M,lat0,lon0)
MC=[];l=[];
num=(K+1)*(M+1);
[sb,sl]=XYZtoBLH(sx,sy,sz);
figt=2880/fig;
for i=1:fig
    for j=1:bds_n_s                %-----------------------j is satellite number
        parfor k=figt*i-(figt-1):figt*i %-------------------------k is epoch number
            if BDSP4(k,j)==0
                continue;
            end
            M_col=linspace(0,0,num*fig+gps_n_s+gps_n_r+bds_n_s+bds_n_r);
            [E,A]=Get_EA(sx,sy,sz,x(k,j)*1000,y(k,j)*1000,z(k,j)*1000); %----sx,sy,sz station coordinate ; x,y,z satellite coordinate
            IPPz=asin(6371000*sin(pi/2-E)/(6371000+450000));%-----SLM 
            t_r=30*(k-1)*pi/43200;
            [b,s]=Get_IPP(E,A,sb,sl,IPPz,t_r);%
            M_col(gps_n_r+gps_n_s+ith)=(-8.99768938)*cos(IPPz);   %-----station dcb coefficient
            M_col(gps_n_r+gps_n_s+bds_n_r+j)=(-8.99768938)*cos(IPPz); %---satallite dcb coefficient
            st=num*(i-1)+gps_n_r+gps_n_s+bds_n_r+bds_n_s+1;
            ed=num*i+gps_n_r+gps_n_s+bds_n_r+bds_n_s;
            M_col(st:ed)=Get_POLY(b,s,K,M,lat0,lon0);
            M_scol=sparse(M_col);
            MC=[MC;M_scol]; 
            l=[l;BDSP4(k,j)*(-8.99768938)*cos(IPPz)];
        end
    end
end
end

%% ------------------------------sub_function--------------------------------
function cof_P=Get_POLY(b,s,K,M,lat0,lon0)
cof_P=linspace(0,0,(K+1)*(M+1));
diff_b=b-lat0;
diff_s=s-lon0;
m=1;
for i=0:K
    for j=0:M
        cof_P(m)=diff_b^i*diff_s^j;
        m=m+1;
    end
end
end
