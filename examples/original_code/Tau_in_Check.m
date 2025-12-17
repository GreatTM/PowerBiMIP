clc;
% cal_buildingParam(0.02, 0.02, 1, 20);
num_period = 24;
num_building = 26;
Tau_in_opt = data.buildings.limit(3);
Tau_act = data.buildings.Tau_act';
Tau_out = data.buildings.Tau_out;
alpha0 = data.buildings.uncertainty.alpha;
beta0 = data.buildings.uncertainty.beta;
epsilon = 0:0.01:1;
for k = 1:length(var_1st.recourse)
    h_load(:,:,k) = var_1st.recourse(k).building.h_load;
end
%% Tau_in_up
alpha = alpha0(:,2)*(1-epsilon) + alpha0(:,3)*epsilon;
beta = beta0(:,2)*(1-epsilon) + beta0(:,3)*epsilon;
for k_building = 1:num_building
    Tau_in_up(1,:,k_building) = alpha(k_building,:)*Tau_in_opt + ...
        beta(k_building,:)*h_load(1,k_building,1) + ...
        Tau_act(1,k_building)*ones(1,size(alpha,2)) + ...
        (1-alpha(k_building,:))*Tau_out(1,1);
    
    for t = 2:num_period
        Tau_in_up(t,:,k_building) = alpha(k_building,:).*Tau_in_up(t-1,:,k_building) + ...
            beta(k_building,:).*h_load(t,k_building,1) + ...
            Tau_act(t,k_building)*ones(1,size(alpha,2)) + ...
            (1-alpha(k_building,:))*Tau_out(t,1);
    end
end
%% Tau_in_low
alpha = alpha0(:,1)*(1-epsilon) + alpha0(:,4)*epsilon;
beta = beta0(:,1)*(1-epsilon) + beta0(:,4)*epsilon;
for k_building = 1:num_building
    Tau_in_low(1,:,k_building) = alpha(k_building,:)*Tau_in_opt + ...
        beta(k_building,:)*h_load(1,k_building,1) + ...
        Tau_act(1,k_building)*ones(1,size(alpha,2)) + ...
        (1-alpha(k_building,:))*Tau_out(1,1);
    
    for t = 2:num_period
        Tau_in_low(t,:,k_building) = alpha(k_building,:).*Tau_in_low(t-1,:,k_building) + ...
            beta(k_building,:).*h_load(t,k_building,1) + ...
            Tau_act(t,k_building)*ones(1,size(alpha,2)) + ...
            (1-alpha(k_building,:))*Tau_out(t,1);
    end
end
figure(1);
for k_building = 1: num_building
    subplot(2,1,1);
    plot(Tau_in_up(:,:,k_building),'LineWidth',0.2);  hold on;
    subplot(2,1,2);
    plot(Tau_in_low(:,:,k_building),'LineWidth',0.2);  hold on;
end
max_Tau_in = max(max(max(max(Tau_in_up))), max(max(max(Tau_in_low)))) %#ok<*NOPTS>
min_Tau_in = min(min(min(min(Tau_in_low))), min(min(min(Tau_in_up))))
Delta_upper = max_Tau_in - data.buildings.limit(2)
Delta_lower = data.buildings.limit(1) - min_Tau_in

Tau_max_time = max(max(Tau_in_up, [], 3), [], 2);
Tau_min_time = min(min(Tau_in_low, [], 3), [], 2);

grid on;
    
