function [] = read_energinet_data()
% [] = read_energinet_data()
% Reads energinet 2020 model xlsx file and writes matpower case format files
% A copy of the dataset can be acquired from Energinet's homepage;
% https://en.energinet.dk/Electricity/Energy-data/System-data
%
% The Danish transmission system covers 2 synchronous areas and is thus be
% represented in two separate matpower case files.
% 
% Necessary configurations for successful data conversion:
%  - Specify paths to matpower and datafile in this function file. (set 
%       string variables "path_to_file" and "file_name")
%  - Identify indices of one bus in each of the two synchronous areas. The
%       function conducts a BFS with root in those nodes in order to 
%       determine which node belongs to what area. (set integer variables
%       "root_node_in_east" and "root_node_in_west"). 
%       Default settings will most likely suffice.
%  - Be aware that bus numbers in Energinet data start with 0 and are
%       non-consecutive. Matpower requires consecutive bus numbering 
%       starting with 1. To the matpower case format struct is therefore
%       added a field "mpc.bus_map" where the bus index can be traced back
%       to the Energinet bus numbering.
%  - The cost functions of generation is not included in the Energinet
%       data. The cost-functions added here are spoof and only intended to
%       make the case data the matpower data validation. Thus, the case
%       files generated by this function are not suited for optimal power
%       flow studies.
%  - HVDC terminals are all modeled as PQ nodes although SK4 and probably
%       CO are VSC type.
%
%  This code may be redistributed freely and comes with no warranty.
%  If applying the code on data provided by Energinet the user is 
%  accuntable for complying with any requirements or guidelines
%  put forward by Energinet.
%
% Thanks to Energinet for making the data available.
% 
% Jakob Glarbo Møller, Technical University of Denmark, 2017
% jglmo@elektro.dtu.dk

addpath ../matpower6.0/

system_mva_base = 100;

path_to_file = '../data/ENDK_2020/';
file_name = 'endk_2020_ohl_model.xlsx';

root_node_in_east = 1; % dke nodes are assigned root in bus 1(0)
root_node_in_west = 5; % dkw nodes are assidned root in bus 5(4)

% read Line data
[num, ~] = xlsread([path_to_file file_name],'Line');
branch.fbus = num(5:end,1);
branch.tbus = num(5:end,2);

% convert line parameters to pu
z_base = num(5:end,7).^2/system_mva_base;
branch.r = num(5:end,8)./z_base;
branch.x = num(5:end,9)./z_base;
branch.b = 10^(-6)*num(5:end,11).*z_base;
branch.rateA = num(5:end,6).*num(5:end,7);
branch.rateB = 1.1*branch.rateA; % Short-term permissible loadings are not specified in dataset.
branch.rateC = 1.2*branch.rateA; % Short-term permissible loadings are not specified in dataset.
branch.ratio = zeros(size(branch.fbus));
branch.angle = zeros(size(branch.fbus));
branch.status = ones(size(branch.fbus));
branch.angmin = -360*ones(size(branch.fbus));
branch.angmax = -360*ones(size(branch.fbus));

% read 2w-transformers and convert parameters
[num, ~] = xlsread([path_to_file file_name],'Transformer2');

dU = num(5:end,15).*0.01;
d_angle = num(5:end,16);
neutral_tap = num(5:end,13);
actual_tap = num(5:end,14);
ratio = 1.0 + (actual_tap - neutral_tap) .* dU;
angle = (actual_tap - neutral_tap) .* mod(d_angle,180);
trafo_mva = num(5:end,6);
z_base_trafo = num(5:end,4).^2./trafo_mva;
z_base_system = num(5:end,4).^2./system_mva_base;

num_trafos = length(dU);

uk = num(5:end,7);
Pcu = num(5:end,8);
z = uk./(100).*z_base_trafo./z_base_system;
r = Pcu./(1000*trafo_mva).*z_base_trafo./z_base_system;
x = sqrt(z.^2 - r.^2);



branch.fbus = [branch.fbus; num(5:end,1)];
branch.tbus = [branch.tbus; num(5:end,2)];
branch.r = [branch.r; r];
branch.x = [branch.x; x];
branch.b = [branch.b; zeros(size(r))];
branch.ratio = [branch.ratio; ratio];
branch.angle = [branch.angle; angle];

[branch.r(end-num_trafos:end) branch.x(end-num_trafos:end)]

% read 3w-trafos and convert parameters
[num, str] = xlsread([path_to_file file_name],'Transformer3');

HV_bus = num(5:end,1);
MV_bus = num(5:end,2);
LV_bus = num(5:end,3);

trafo_mva = num(5:end,8);

HV_uk = num(5:end,9);
HV_Pcu = num(5:end,12);

z_base_trafo = num(5:end,5).^2./trafo_mva;
z_base_system = num(5:end,5).^2./system_mva_base;
z_hm = (HV_uk./100).*(z_base_trafo./z_base_system);
r_hm = (HV_Pcu./(1000*trafo_mva)).*(z_base_trafo./z_base_system);
x_hm = sqrt(z_hm.^2 - r_hm.^2);

MV_uk = num(5:end,10);
MV_Pcu = num(5:end,13);

z_hl = (MV_uk./100).*(z_base_trafo./z_base_system);
r_hl = (MV_Pcu./(1000*trafo_mva)).*(z_base_trafo./z_base_system);
x_hl = sqrt(z_hl.^2 - r_hl.^2);

LV_uk = num(5:end,11);
LV_Pcu = num(5:end,14);

z_base_system = num(5:end,6).^2./system_mva_base;
z_base_trafo = num(5:end,6).^2./trafo_mva;
z_ml = (LV_uk./100).*(z_base_trafo./z_base_system);
r_ml = (LV_Pcu./(1000*trafo_mva)).*(z_base_trafo./z_base_system);
x_ml = sqrt(z_ml.^2 - r_ml.^2);

ratio_data = 1 + (num(5:end,21)-num(5:end,20)).*num(5:end,22)/100;
ratio = ones(3*length(HV_bus),1);

% assign off nominal ratio to tapped winding
for k = 1:length(HV_bus)
    switch str{4+k,17}
        case 'HV'
            ratio(k) = ratio_data(k);
        case 'MV'
            ratio(length(HV_bus)+k) = ratio_data(k);
        case 'LV'
            ratio(length(HV_bus)+length(MV_bus)+k) = ratio_data(k);        
    end
end

% 3wtrafos are converted to 3 2w-trafos:
% [HV->MV; HV->LV; MV->LV]
fbus = [HV_bus; HV_bus; MV_bus];
tbus = [MV_bus; LV_bus; LV_bus];
r = [r_hm; r_hl; r_ml];
x = [x_hm; x_hl; x_ml];

num_trafos = num_trafos + length(fbus);

branch.fbus = [branch.fbus; fbus];
branch.tbus = [branch.tbus; tbus];
branch.r = [branch.r; r];
branch.x = [branch.x; x];
branch.b = [branch.b; zeros(size(r))];
branch.ratio = [branch.ratio; ratio];
branch.angle = [branch.angle; zeros(size(ratio))];
branch.rateA = [branch.rateA; zeros(num_trafos,1)];
branch.rateB = [branch.rateB; zeros(num_trafos,1)];
branch.rateC = [branch.rateC; zeros(num_trafos,1)];
branch.status = ones(size(branch.fbus));
branch.angmin = -360*ones(size(branch.fbus));
branch.angmax = 360*ones(size(branch.fbus));


% 0-impedance branches are assigned a small non-0 impedance
branch.x(branch.x<1e-4)=1e-4;
%branch.r(branch.r<1e-5)=1e-5;


%%% Assigning nodes to synchronous area - DK-east and DK-west by tree
%%% searh at to individual nodes known to be in east and west respectively:

% construct branch incidence matrix
b = length(branch.fbus);
branch_bus_incidence_matrix = sparse(1:b, branch.fbus+1, ones(1,b),b,b) - sparse(1:b, branch.tbus+1, ones(1,b),b,b);

branch_table = [branch.fbus branch.tbus branch.r branch.x branch.b branch.rateA branch.rateB branch.rateC branch.ratio branch.angle branch.status branch.angmin branch.angmax];
clear branch

% identifying buses in dke and dkw
bus_laplacian = branch_bus_incidence_matrix'*branch_bus_incidence_matrix;
[froms,tos] = find(bus_laplacian);

% find buses in DKE
r = root_node_in_east;
simple_graph = 3*sparse(froms,tos,ones(length(ones)));
grey_nodes = r;
black_nodes = [];
while ~isempty(grey_nodes)
    c = grey_nodes(1);
    if simple_graph(c,c)>1
        new_greys = find(simple_graph(c,:)==3);
        simple_graph(new_greys,c) = 2;
        simple_graph(c,c) = 1;
        grey_nodes = [grey_nodes, new_greys];
        black_nodes = [black_nodes c];
    end
    grey_nodes(1) = [];
end

dke_nodes = sort(black_nodes-1);

% find buses in DKW
r = root_node_in_west;
simple_graph = 3*sparse(froms,tos,ones(length(ones)));
grey_nodes = r;
black_nodes = [];
while ~isempty(grey_nodes)
    c = grey_nodes(1);
    if simple_graph(c,c)>1
        new_greys = find(simple_graph(c,:)==3);
        simple_graph(new_greys,c) = 2;
        simple_graph(c,c) = 1;
        grey_nodes = [grey_nodes, new_greys];
        black_nodes = [black_nodes c];
    end
    grey_nodes(1) = [];
end

dkw_nodes = sort(black_nodes-1);


[num, str] = xlsread([path_to_file file_name],'Bus');

bus.numbers = num(5:end,1);
bus.type = ones(size(bus.numbers)); % updated after reading generator data
bus.Pd = zeros(size(bus.numbers)); % updated after reading load data
bus.Qd = zeros(size(bus.numbers)); % updated after reading load data
bus.Gs = zeros(size(bus.numbers)); % updated after reading shunt data
bus.Bs = zeros(size(bus.numbers)); % updated after reading shunt data

bus_area_names = str(5:end,4);
% convert area names to area numbers
bus.area_number = [];
sorted_bus_area_names = sort(bus_area_names);
h = 1;
area_names{h} = sorted_bus_area_names{1};
for k =2:length(sorted_bus_area_names)
    if ~strcmp(sorted_bus_area_names{k},sorted_bus_area_names{k-1})
        h=h+1; 
        area_names{h} = sorted_bus_area_names{k};
    end
end
% TODO area_names should be provided for reference as comment in mpc file

for k = 1:length(bus_area_names)
    area_num = find(strcmp(bus_area_names{k},area_names));
    bus.area_number = [bus.area_number; area_num];
end

bus.Vm = ones(size(bus.numbers)); % updated after reading generator data
bus.Va = zeros(size(bus.numbers)); 
bus.baseKV = num(5:end,5);
bus.zone = ones(size(bus.numbers));
bus.Vmax = num(5:end,7);
bus.Vmin = num(5:end,6);
bus.names = str(5:end,2);
bus.station_names = str(5:end,3);


[num, ~] = xlsread([path_to_file file_name],'Load');
load_bus = num(5:end,1);
load_P = num(5:end,4);
load_Q = num(5:end,5);
for k = 1:length(bus.Pd)
    bus.Pd(k) = sum(load_P(load_bus==bus.numbers(k)));
    bus.Qd(k) = sum(load_Q(load_bus==bus.numbers(k)));
end

% HVDC represented as loads
[num, ~] = xlsread([path_to_file file_name],'HVDC');
hvdc_bus = num(5:end,1);
hvdc_P = num(5:end,5);
hvdc_Q = num(5:end,6);
for k = 1:length(hvdc_bus)
    bus.Pd(bus.numbers==hvdc_bus(k)) = bus.Pd(bus.numbers==hvdc_bus(k)) + hvdc_P(k);
    bus.Qd(bus.numbers==hvdc_bus(k)) = bus.Qd(bus.numbers==hvdc_bus(k)) + hvdc_Q(k);
end

[num, ~] = xlsread([path_to_file file_name],'Shunt');
shunt_bus = num(5:end,1);
actual_step = num(5:end,5);
max_step = num(5:end,4);
Bs = ( -num(5:end,6)+num(5:end,7));
shunt_compensation = (actual_step .* Bs./max_step);
for k = 1:length(bus.Bs)
    bus.Bs(k) = sum(shunt_compensation(shunt_bus==bus.numbers(k)));
end

[num, str] = xlsread([path_to_file file_name],'Generator');
generators.bus = num(5:end,1);
generators.name = str(5:end,2);
generators.Pg = num(5:end,10);
generators.Qg = num(5:end,11);
generators.mbase = system_mva_base*ones(size(generators.bus));
generators.status = ones(size(generators.bus));
generators.Pmax = num(5:end,7);
generators.Pmin = num(5:end,6);
generators.Qmax = num(5:end,9);
generators.Qmin = num(5:end,8);

controlled_bus = num(5:end,12);
scheduled_voltages = num(5:end,13);
scheduled_voltages(isnan(scheduled_voltages))=1.0;
control_type_str = str(5:end,3);
generators.control_type = [];

for c = 1:length(control_type_str)
    switch control_type_str{c}
        case 'PQ'
            bus.type(bus.numbers==generators.bus(c)) = 1;
        case 'PV'
            bus.type(bus.numbers==generators.bus(c)) = 2;
            bus.Vm(bus.numbers==generators.bus(c)) = scheduled_voltages(c);            
            bus.Vm(bus.numbers==controlled_bus(c)) = scheduled_voltages(c);
        case 'SL'
            bus.type(bus.numbers==generators.bus(c)) = 3;
            bus.Vm(bus.numbers==controlled_bus(c)) = scheduled_voltages(c);
    end
end

gen_types = {'solar' 'WindOn' 'WindOff' 'gas' 'hydro' 'other'};
generator_type = zeros(size(generators.bus));
for c = 1:length(generators.bus)
    name = generators.name{c};
    for gtype = 1:length(gen_types)
        if strfind(name,gen_types{gtype})
            generator_type(c) = gtype;
        end
    end
end


% done reading - start writing:

generators_table = [generators.bus generators.Pg generators.Qg generators.Qmax generators.Qmin scheduled_voltages generators.mbase generators.status  generators.Pmax generators.Pmin generator_type];
clear generators

n = length(bus.numbers);

bus_table = [bus.numbers bus.type bus.Pd bus.Qd bus.Gs bus.Bs bus.area_number bus.Vm bus.Va bus.baseKV bus.zone bus.Vmax bus.Vmin];
east.bus = [];
west.bus = [];
east.bus_names = [];
west.bus_names = [];

for k = 1:n
    data_line = bus_table(k,:);
    if find(dke_nodes==data_line(1))
        east.bus = [ east.bus; data_line];
        east.bus_names = [east.bus_names; bus.names(k)];
    elseif find(dkw_nodes==data_line(1))
        west.bus = [ west.bus; data_line];
        west.bus_names = [west.bus_names; bus.names(k)];        
    else
       fprintf('Warning! ignored node: %d. Is it not connected? \n', data_line(1));
    end
end

% re-number buses consecutively
east.bus_numbers = east.bus(:,1);
east.bus(:,1) = 1:length(east.bus_numbers);
west.bus_numbers = west.bus(:,1);
west.bus(:,1) = 1:length(west.bus_numbers);

% create bus-maps for refering matpower busnumbering with ENDK bus
% numbering
east.bus_map = [east.bus(:,1) east.bus_numbers];
west.bus_map = [west.bus(:,1) west.bus_numbers];


east.branch = [];
west.branch = [];
for k = 1:length(branch_table(:,1))
    data_line = branch_table(k,:);
    if ~isempty(find(dke_nodes==data_line(1),1)) && ~isempty(find(dke_nodes==data_line(2),1))
        data_line(1) = east.bus_map(east.bus_map(:,2) == data_line(1),1);
        data_line(2) = east.bus_map(east.bus_map(:,2) == data_line(2),1);
        east.branch = [ east.branch; data_line];
    elseif ~isempty(find(dkw_nodes==data_line(1),1)) && ~isempty(find(dkw_nodes==data_line(2),1))
        data_line(1) = west.bus_map(west.bus_map(:,2) == data_line(1),1);
        data_line(2) = west.bus_map(west.bus_map(:,2) == data_line(2),1);
        west.branch = [ west.branch; data_line];
    else
        fprintf(1, 'Warning! ignored line: %d-%d \n', branch.fbus(k), branch.tbus(k));
    end
end
   
east.generator = [];
west.generator = [];
for k = 1:length(generators_table(:,1))
    data_line = generators_table(k,:);
    if ~isempty(find(dke_nodes==data_line(1),1))
        data_line(1) = east.bus_map(east.bus_map(:,2) == data_line(1),1);
        east.generator = [ east.generator; data_line];
    elseif ~isempty(find(dkw_nodes==data_line(1),1))
        data_line(1) = west.bus_map(west.bus_map(:,2) == data_line(1),1);
        west.generator = [ west.generator; data_line];
    else
        fprintf(1, 'Warning! ignored generator: %d\n', generators_table(k,1));
    end    
end

east.gentypes = east.generator(:,end);
east.generator(:,end)=[];
west.gentypes = west.generator(:,end);
west.generator(:,end)=[];

% Cost Functions:
%     1  MODEL       cost model, 1 = piecewise linear, 2 = polynomial
%     2  STARTUP     startup cost in US dollars
%     3  SHUTDOWN    shutdown cost in US dollars
%     4  NCOST       number of cost coefficients to follow for polynomial cost
%                    function, or number of data points for piecewise linear
%     5  COST        parameters defining total cost function begin in this col
%                   (MODEL = 1) : p0, f0, p1, f1, ..., pn, fn
%                        where p0 < p1 < ... < pn and the cost f(p) is defined
%                        by the coordinates (p0,f0), (p1,f1), ..., (pn,fn) of
%                        the end/break-points of the piecewise linear cost
%                   (MODEL = 2) : cn, ..., c1, c0
%                        n+1 coefficients of an n-th order polynomial cost fcn,
%                        starting with highest order, where cost is
%                        f(p) = cn*p^n + ... + c1*p + c0


cost_functions = [
            2 8e3 0 2 0.0 80  15 ; % central
            2 0   0 2 0.0 100 100; % solar
            2 0   0 2 0.0 40  20 ; % WindOn
            2 0   0 2 0.0 130 40 ; % WindOff
            2 6e3 0 2 0.0 80  10 ; % gas
            2 0   0 2 0.0 40  20 ; % hydro
            2 6e3 0 2 0.0 80  10 ];% other
   
        
dk_east_file_id = fopen('case_dk_east.m','w+');
fprintf(dk_east_file_id,'function [mpc] = case_dk_east()\n');

fprintf(dk_east_file_id,'mpc.version = ''2'';\n');
fprintf(dk_east_file_id,'mpc.baseMVA = %10.4f;\n', system_mva_base);

fprintf(dk_east_file_id,'%%%% bus data\n');
fprintf(dk_east_file_id,'%%   bus_i  type     Pd          Qd        Gs          Bs   area        Vm         Va      baseKV   zone      Vmax      Vmin\n');
fprintf(dk_east_file_id,'mpc.bus = [ \n');

for k = 1:length(east.bus(:,1))
    % bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
    fprintf(dk_east_file_id, '%8d %4d %10.4f %10.4f %10.4f %10.4f %4d  %10.4f %10.4f %10.4f %4d  %10.4f %10.4f \n', east.bus(k,:));
end
fprintf(dk_east_file_id,'];\n');

fprintf(dk_east_file_id, '%%	fbus      tbus       r          x          b        rateA      rateB      rateC      ratio      angle status angmin      angmax\n');
fprintf(dk_east_file_id,'mpc.branch = [ \n');
for k = 1:length(east.branch(:,1))
                    %	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax	Pf	Qf	Pt	Qt	mu_Sf	mu_St	mu_angmin	mu_angmax
    fprintf(dk_east_file_id,' %8d %8d %10.4f %10.4f %10.4f %10.0f %10.0f %10.0f %10.4f %10.4f %4d %10.4f %10.4f\n',east.branch(k,:));
end
fprintf(dk_east_file_id,'];\n');

%[generators.bus generators.Pg generators.Qg generators.Qmin generators.Qmax scheduled_voltages generators.mbase generators.status generators.Pmin generators.Pmax]
fprintf(dk_east_file_id, '%%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin\n');
fprintf(dk_east_file_id,'mpc.gen = [ \n');
for k = 1:length(east.generator(:,1))
                    %	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin
    fprintf(dk_east_file_id,' %8d %10.4f %10.4f %10.4f %10.4f %10.4f %10.4f %4d %10.4f %10.4f \n',east.generator(k,:));
end
fprintf(dk_east_file_id,'];\n');


fprintf(dk_east_file_id,'mpc.gencost = [ \n');
for k = 1:length(east.generator(:,1))
    fprintf(dk_east_file_id,' %4d %10.4f %10.4f %4d %10.4f %10.4f %10.4f\n', cost_functions(east.gentypes(k)+1,:));
end
fprintf(dk_east_file_id,'];\n');


fprintf(dk_east_file_id,'mpc.bus_map = [ \n');
for k = 1:length(east.bus(:,1))
    fprintf(dk_east_file_id, '%8d %8d %% %s\n', east.bus_map(k,:), east.bus_names{k});
end
fprintf(dk_east_file_id,'];\n');


gentype_names = {'central' gen_types{:}};

fprintf(dk_east_file_id,'mpc.gen_types = [ \n');
for k = 1:length(east.gentypes)
    fprintf(dk_east_file_id, '%8d %% %s\n', east.gentypes(k), gentype_names{east.gentypes(k)+1});
end
fprintf(dk_east_file_id,'];\n');

fprintf(dk_east_file_id,'%% area_names: \n');
for k = 1:length(area_names)
    fprintf(dk_east_file_id, '%% %8d %% %s\n', k, area_names{k});
end
fprintf(dk_east_file_id,'\n');

fclose(dk_east_file_id);
clear east

%%%%%%%
dk_west_file_id = fopen('case_dk_west.m','w+');

fprintf(dk_west_file_id,'function [mpc] = case_dk_west()\n');

fprintf(dk_west_file_id,'mpc.version = ''2'';\n');
fprintf(dk_west_file_id,'mpc.baseMVA = %10.4f;\n', system_mva_base);

fprintf(dk_west_file_id,'%%%% bus data\n');
fprintf(dk_west_file_id,'%%   bus_i  type     Pd          Qd        Gs          Bs   area        Vm         Va      baseKV   zone      Vmax      Vmin\n');
fprintf(dk_west_file_id,'mpc.bus = [ \n');

for k = 1:length(west.bus(:,1))
    % bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
    fprintf(dk_west_file_id, '%8d %4d %10.4f %10.4f %10.4f %10.4f %4d  %10.4f %10.4f %10.4f %4d  %10.4f %10.4f \n', west.bus(k,:));
end
fprintf(dk_west_file_id,'];\n');

fprintf(dk_west_file_id, '%%	fbus      tbus       r          x          b        rateA      rateB      rateC      ratio      angle status angmin      angmax\n');
fprintf(dk_west_file_id,'mpc.branch = [ \n');
for k = 1:length(west.branch(:,1))
                    %	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax	Pf	Qf	Pt	Qt	mu_Sf	mu_St	mu_angmin	mu_angmax
    fprintf(dk_west_file_id,' %8d %8d %10.4f %10.4f %10.4f %10.4f %10.4f %10.4f %10.4f %10.4f %4d %10.4f %10.4f\n',west.branch(k,:));
end
fprintf(dk_west_file_id,'];\n');

%[generators.bus generators.Pg generators.Qg generators.Qmin generators.Qmax scheduled_voltages generators.mbase generators.status generators.Pmin generators.Pmax]
fprintf(dk_west_file_id, '%%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin\n');
fprintf(dk_west_file_id,'mpc.gen = [ \n');
for k = 1:length(west.generator(:,1))
                    %	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin
    fprintf(dk_west_file_id,' %8d %10.4f %10.4f %10.4f %10.4f %10.4f %10.4f %4d %10.4f %10.4f\n',west.generator(k,:));
end
fprintf(dk_west_file_id,'];\n');


fprintf(dk_west_file_id,'mpc.gencost = [ \n');
for k = 1:length(west.generator(:,1))
     fprintf(dk_west_file_id,' %4d %10.4f %10.4f %4d %10.4f %10.4f %10.4f\n',cost_functions(west.gentypes(k)+1,1:6),cost_functions(west.gentypes(k)+1,7).*west.generator(k,9));

end
fprintf(dk_west_file_id,'];\n');


fprintf(dk_west_file_id,'mpc.bus_map = [ \n');
for k = 1:length(west.bus(:,1))
fprintf(dk_east_file_id, '%8d %8d %% %s\n', west.bus_map(k,:), west.bus_names{k});
    %    fprintf(dk_west_file_id, '%8d %8d\n', west.bus_map(k,:));
end
fprintf(dk_west_file_id,'];\n');

fprintf(dk_west_file_id,'mpc.gen_types = [ \n');
for k = 1:length(west.gentypes)
    fprintf(dk_west_file_id, '%8d %% %s\n', west.gentypes(k), gentype_names{west.gentypes(k)+1});
end
fprintf(dk_west_file_id,'];\n');

fprintf(dk_east_file_id,'%% area_names: \n');
for k = 1:length(area_names)
    fprintf(dk_east_file_id, '%% %8d %% %s\n', k, area_names{k});
end
fprintf(dk_east_file_id,'\n');

fclose(dk_west_file_id);

end


