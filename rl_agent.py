import os
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO

env = StableBaselinesGodotEnv(env_path=None, show_window=True, speedup=8)

model = PPO(
    "MultiInputPolicy",
    env,
    verbose=1,
    learning_rate=0.0003,
    n_steps=2048,
    batch_size=64,
    ent_coef=0.01
)

print("--- Starting Training: Connection Established ---")
try:
    model.learn(total_timesteps=100000)
    print("--- Training Complete! ---")
except KeyboardInterrupt:
    print("--- Training Interrupted: Saving progress... ---")

model.save("monopoly_ai_brain")
print("Model saved as 'monopoly_ai_brain.zip'")

env.close()