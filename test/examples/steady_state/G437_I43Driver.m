% File generated by Facile version 0.53
%
% initial values (free nodes only)
G1137_0x = 1.0484020445962;
TG0000_1 = 0;
G1137_0x_TG0000_1_i00 = 0;
TG0000_0 = 1.00677529813686;
G3354_x = 0.0960295054102669;
G3354_x_TG0000_0_i00 = 0;
G0166_xxxx = 177.528000718041;
G0166_xxxx_G1137_0x_i00 = 0;
G0166_xxxx_G3354_x_i00 = 0;
G3786_x = 973.351706707066;
G0166_xxxx_G3786_x_i00 = 0;
LG0000_x = 0.001;
G0166_xxxx_LG0000_x_i00 = 0;
G0166_xxxx_LG0000_x_i01 = 0;
G3786_x_LG0000_x_i00 = 0;
G0166_xxxx_G1137_0x_G3354_x_i00 = 0;
G0166_xxxx_G1137_0x_LG0000_x_i00 = 0;
G0166_xxxx_G1137_0x_LG0000_x_i01 = 0;
G0166_xxxx_G3354_x_G3786_x_i00 = 0;
G0166_xxxx_G3354_x_LG0000_x_i00 = 0;
G0166_xxxx_G3354_x_LG0000_x_i01 = 0;
G0166_xxxx_G3786_x_LG0000_x_i00 = 0;
G0166_xxxx_G3786_x_LG0000_x_i01 = 0;
G0166_xxxx_LG0000_x_LG0000_x_i00 = 0;
G0166_xxxx_G1137_0x_G3354_x_LG0000_x_i00 = 0;
G0166_xxxx_G1137_0x_G3354_x_LG0000_x_i01 = 0;
G0166_xxxx_G1137_0x_LG0000_x_LG0000_x_i00 = 0;
G0166_xxxx_G3354_x_G3786_x_LG0000_x_i00 = 0;
G0166_xxxx_G3354_x_G3786_x_LG0000_x_i01 = 0;
G0166_xxxx_G3354_x_LG0000_x_LG0000_x_i00 = 0;
G0166_xxxx_G3786_x_LG0000_x_LG0000_x_i00 = 0;
if exist('ivalues') == 0
ivalues = [G1137_0x TG0000_1 G1137_0x_TG0000_1_i00 TG0000_0 G3354_x G3354_x_TG0000_0_i00 G0166_xxxx G0166_xxxx_G1137_0x_i00 ...
	G0166_xxxx_G3354_x_i00 G3786_x G0166_xxxx_G3786_x_i00 LG0000_x G0166_xxxx_LG0000_x_i00 G0166_xxxx_LG0000_x_i01 G3786_x_LG0000_x_i00 G0166_xxxx_G1137_0x_G3354_x_i00 ...
	G0166_xxxx_G1137_0x_LG0000_x_i00 G0166_xxxx_G1137_0x_LG0000_x_i01 G0166_xxxx_G3354_x_G3786_x_i00 G0166_xxxx_G3354_x_LG0000_x_i00 G0166_xxxx_G3354_x_LG0000_x_i01 G0166_xxxx_G3786_x_LG0000_x_i00 G0166_xxxx_G3786_x_LG0000_x_i01 G0166_xxxx_LG0000_x_LG0000_x_i00 ...
	G0166_xxxx_G1137_0x_G3354_x_LG0000_x_i00 G0166_xxxx_G1137_0x_G3354_x_LG0000_x_i01 G0166_xxxx_G1137_0x_LG0000_x_LG0000_x_i00 G0166_xxxx_G3354_x_G3786_x_LG0000_x_i00 G0166_xxxx_G3354_x_G3786_x_LG0000_x_i01 G0166_xxxx_G3354_x_LG0000_x_LG0000_x_i00 G0166_xxxx_G3786_x_LG0000_x_LG0000_x_i00];
end
% rate constants and constant expressions
fb00= 0.125892541179417;
bb00= 31.6227766016838;
kp00= 5.09031745856789;
fb01= 3.98107170553497;
bb01= 1.99526231496888;
kp01= 20.7355491991768;
fb02= 0.501187233627272;
bb02= 63.0957344480193;
fb03= 63.0957344480193;
bb03= 0.00794328234724281;
fb04= 15.8489319246111;
bb04= 0.0630957344480193;
bb05= 0.125892541179417;
bb06= 0.501187233627272;
fb05= 0.251188643150958;
clamp_sink_LG0000_x= 4.0;
global ode_rate_constants;
ode_rate_constants = [fb00 bb00 kp00 fb01 bb01 kp01 fb02 bb02 fb03 bb03 fb04 bb04 ...
	bb05 bb06 fb05 clamp_sink_LG0000_x];

% time interval
t0= 0;
tf= 200000;

% call solver routine 
global event_times;
global event_flags;
[t, y, intervals]= G437_I43_ode_event(@ode23s, @G437_I43_odes, [t0:10.0:tf], ivalues, odeset('AbsTol',1e-6,'MaxStep',100.0,'RelTol',1e-3,'InitialStep',1e-8), [0 0 0 0 0 0 0], [], [], []);

% map free node state vector names
G1137_0x = y(:,1); TG0000_1 = y(:,2); G1137_0x_TG0000_1_i00 = y(:,3); TG0000_0 = y(:,4); G3354_x = y(:,5); G3354_x_TG0000_0_i00 = y(:,6); G0166_xxxx = y(:,7); G0166_xxxx_G1137_0x_i00 = y(:,8); G0166_xxxx_G3354_x_i00 = y(:,9); G3786_x = y(:,10); 
G0166_xxxx_G3786_x_i00 = y(:,11); LG0000_x = y(:,12); G0166_xxxx_LG0000_x_i00 = y(:,13); G0166_xxxx_LG0000_x_i01 = y(:,14); G3786_x_LG0000_x_i00 = y(:,15); G0166_xxxx_G1137_0x_G3354_x_i00 = y(:,16); G0166_xxxx_G1137_0x_LG0000_x_i00 = y(:,17); G0166_xxxx_G1137_0x_LG0000_x_i01 = y(:,18); G0166_xxxx_G3354_x_G3786_x_i00 = y(:,19); G0166_xxxx_G3354_x_LG0000_x_i00 = y(:,20); 
G0166_xxxx_G3354_x_LG0000_x_i01 = y(:,21); G0166_xxxx_G3786_x_LG0000_x_i00 = y(:,22); G0166_xxxx_G3786_x_LG0000_x_i01 = y(:,23); G0166_xxxx_LG0000_x_LG0000_x_i00 = y(:,24); G0166_xxxx_G1137_0x_G3354_x_LG0000_x_i00 = y(:,25); G0166_xxxx_G1137_0x_G3354_x_LG0000_x_i01 = y(:,26); G0166_xxxx_G1137_0x_LG0000_x_LG0000_x_i00 = y(:,27); G0166_xxxx_G3354_x_G3786_x_LG0000_x_i00 = y(:,28); G0166_xxxx_G3354_x_G3786_x_LG0000_x_i01 = y(:,29); G0166_xxxx_G3354_x_LG0000_x_LG0000_x_i00 = y(:,30); 
G0166_xxxx_G3786_x_LG0000_x_LG0000_x_i00 = y(:,31); 





% issue done message for calling/wrapper scripts
disp('Facile driver script done');

