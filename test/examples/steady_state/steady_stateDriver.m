% File generated by Facile version 0.53
%
% initial values (free nodes only)
X = 4;
Y = 5;
Z = 2;
if exist('ivalues') == 0
ivalues = [X Y Z];
end
% rate constants and constant expressions
k_sinkx= 1;
k_sinky= 3.3;
k_sinkz= 2.2;
global ode_rate_constants;
ode_rate_constants = [k_sinkx k_sinky k_sinkz];

% time interval
t0= 0;
tf= 1000.0;

% call solver routine 
global event_times;
global event_flags;
[t, y, intervals]= steady_state_ode_event(@ode23s, @steady_state_odes, [t0:0.01:tf], ivalues, odeset('AbsTol',1e-12,'RelTol',1e-6), [0 50.0 0 -90 0 300 0], [100], [1e-4], [1e-6]);

% map free node state vector names
X = y(:,1); Y = y(:,2); Z = y(:,3); 



% plot free nodes
figure(100);plot(t, X, '.-');title('X')
figure(101);plot(t, Y, '.-');title('Y')
figure(102);plot(t, Z, '.-');title('Z')


% issue done message for calling/wrapper scripts
disp('Facile driver script done');

