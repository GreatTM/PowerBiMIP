load('results.mat');
%%
ratio_res_pos = model.uncertainty_set(end).p_res_pos;
ratio_res_neg = model.uncertainty_set(end).p_res_neg;
ratio_load_pos = model.uncertainty_set(end).p_load_pos;
ratio_load_neg = model.uncertainty_set(end).p_load_neg;
ratio_Tau_out_pos = model.uncertainty_set(end).Tau_out_pos;
ratio_Tau_out_neg = model.uncertainty_set(end).Tau_out_neg;
ratio_Tau_act_pos = model.uncertainty_set(end).Tau_act_pos;
ratio_Tau_act_neg = model.uncertainty_set(end).Tau_act_neg;
p_res_base = data.profiles.data(34:37,:)';
p_load_base = data.profiles.data(1:33,:)';
Tau_out_base = data.profiles.data(38,:)';
Tau_act_base = data.buildings.Tau_act';
%% 
Deviation_p_res = data.uncertainty.Deviation.p_res;
Deviation_p_load = data.uncertainty.Deviation.p_load;
Deviation_Tau_out = data.uncertainty.Deviation.Tau_out;
Deviation_Tau_act = data.uncertainty.Deviation.Tau_act;
p_res = p_res_base.*(1 + Deviation_p_res*(ratio_res_pos - ratio_res_neg));
p_load = p_load_base.*(1 + Deviation_p_load*(ratio_load_pos - ratio_load_neg));
Tau_out = Tau_out_base.*(1 + Deviation_Tau_out*(ratio_Tau_out_pos - ratio_Tau_out_neg));
Tau_act = Tau_act_base.*(1 + Deviation_Tau_act*(ratio_Tau_act_pos - ratio_Tau_act_neg));

%%
sum_p_res_base = sum(p_res_base,2);
sum_p_load_base = sum(p_load_base,2);
sum_Tau_out_base = sum(Tau_out_base,2);
sum_Tau_act_base = sum(Tau_act_base,2);
%%
sum_p_res = sum(p_res,2);
sum_p_load = sum(p_load,2);
sum_Tau_out = sum(Tau_out,2);
sum_Tau_act = sum(Tau_act,2);
%%
temp = [sum_p_res_base sum_p_res sum_p_load_base sum_p_load ...
    sum_Tau_out_base sum_Tau_out sum(sum_Tau_act_base,2)/26 sum(sum_Tau_act,2)/26];
%%
subplot(2,2,1);
% plot(p_res, 'LineWidth',2); hold on;
% plot(p_res_base, 'LineStyle', '-.', 'LineWidth',2);
% grid on;
plot(sum(p_res,2), 'LineWidth',2); hold on;
plot(sum(p_res_base,2), 'LineStyle', '-.', 'LineWidth',2);
grid on;

subplot(2,2,2);
plot(sum(p_load,2), 'LineWidth',2); hold on;
plot(sum(p_load_base,2), 'LineStyle', '-.', 'LineWidth',2);
grid on;

subplot(2,2,3);
plot(sum(Tau_out,2), 'LineWidth',2); hold on;
plot(sum(Tau_out_base,2), 'LineStyle', '-.', 'LineWidth',2);
grid on;

subplot(2,2,4);
plot(sum(Tau_act,2), 'LineWidth',2); hold on;
plot(sum(Tau_act_base,2), 'LineStyle', '-.', 'LineWidth',2);
grid on;