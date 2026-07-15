import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final projects = appState.projects;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text("WORK",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.muted)),
          const SizedBox(height: 4),
          const Text("Projects", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(projects.isEmpty ? "Track what needs to get done" : "${projects.length} project${projects.length == 1 ? '' : 's'} in progress",
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 18),
          if (projects.isEmpty)
            emptyState("No projects yet. Add one to track your work.")
          else
            ...projects.map((p) => _projectCard(context, appState, p)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showAppBottomSheet(context, const _NewProjectSheet()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.line, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add, color: AppColors.muted),
              label: const Text("New project", style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectCard(BuildContext context, AppState appState, ProjectItem p) {
    final open = _expanded.contains(p.id);
    final color = Color(p.colorValue);
    final pct = (p.progress * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => open ? _expanded.remove(p.id) : _expanded.add(p.id)),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                Text("$pct%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.chevron_right, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: p.progress,
                backgroundColor: AppColors.surface2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _projectBody(context, appState, p),
          ),
        ],
      ),
    );
  }

  Widget _projectBody(BuildContext context, AppState appState, ProjectItem p) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.desc.isNotEmpty) ...[
            Text(p.desc, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5)),
            const SizedBox(height: 10),
          ],
          if (p.tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text("No tasks yet.", style: TextStyle(color: AppColors.muted, fontSize: 13)),
            )
          else
            ...p.tasks.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => appState.toggleProjectTask(p.id, t.id),
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.done ? Color(p.colorValue) : AppColors.field,
                            border: Border.all(color: t.done ? Color(p.colorValue) : AppColors.line, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: t.done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t.text,
                            style: TextStyle(
                                fontSize: 14.5,
                                color: t.done ? AppColors.muted : AppColors.text,
                                decoration: t.done ? TextDecoration.lineThrough : null)),
                      ),
                      GestureDetector(
                        onTap: () => appState.deleteProjectTask(p.id, t.id),
                        child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(hintText: "Add a task…", isDense: true),
                  onSubmitted: (v) {
                    final text = v.trim();
                    if (text.isNotEmpty) appState.addProjectTask(p.id, text);
                    ctrl.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = ctrl.text.trim();
                  if (text.isNotEmpty) appState.addProjectTask(p.id, text);
                  ctrl.clear();
                },
                child: const Text("Add"),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: "Delete project?", message: "Delete '${p.name}'?", confirmLabel: "Delete", danger: true);
                if (ok) await appState.deleteProject(p.id);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              child: const Text("Delete project"),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet();

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Color _color = kProjectColors.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("New project", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, maxLength: 80, autofocus: true, decoration: const InputDecoration(hintText: "Project name…", counterText: "")),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(hintText: "What is this project about? (optional)")),
          const SizedBox(height: 14),
          const Text("COLOR",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: kProjectColors.map((c) {
              final on = c.value == _color.value;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: on ? AppColors.text : Colors.transparent, width: 3),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  final name = _nameCtrl.text.trim();
                  if (name.isEmpty) {
                    showToast(context, "Give the project a name.");
                    return;
                  }
                  final appState = AppStateScope.read(context);
                  await appState.addProject(name, _descCtrl.text.trim(), _color.value);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text("Create project"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
