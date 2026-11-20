from django.db import migrations, models


def migrate_accepted_applications(apps, schema_editor):
    JobApplication = apps.get_model("rentals", "JobApplication")
    JobPosting = apps.get_model("rentals", "JobPosting")
    database = schema_editor.connection.alias

    accepted = list(
        JobApplication.objects.using(database)
        .filter(status="accepted")
        .order_by("job_id", "created_at", "id")
        .values_list("id", "job_id")
    )
    selected_by_job = {}
    accepted_job_ids = set()
    unselected_ids = []
    for application_id, job_id in accepted:
        accepted_job_ids.add(job_id)
        if job_id in selected_by_job:
            unselected_ids.append(application_id)
        else:
            selected_by_job[job_id] = application_id

    selected_ids = list(selected_by_job.values())
    if selected_ids:
        JobApplication.objects.using(database).filter(id__in=selected_ids).update(status="hired")
    if unselected_ids:
        JobApplication.objects.using(database).filter(id__in=unselected_ids).update(status="job_taken")
    filled_job_ids = list(accepted_job_ids)
    JobPosting.objects.using(database).filter(id__in=filled_job_ids).update(is_active=False)
    JobApplication.objects.using(database).filter(
        job_id__in=filled_job_ids,
    ).exclude(id__in=selected_ids).exclude(
        status__in=["declined", "withdrawn", "job_taken"]
    ).update(status="job_taken")


class Migration(migrations.Migration):
    dependencies = [
        ("rentals", "0046_userpresencesession"),
    ]

    operations = [
        migrations.AddField(
            model_name="servicerequest",
            name="status_history",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="jobapplication",
            name="status_history",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AlterField(
            model_name="servicerequest",
            name="status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("accepted", "Accepted"),
                    ("in_progress", "In progress"),
                    ("completed", "Completed"),
                    ("declined", "Declined"),
                    ("cancelled", "Cancelled"),
                ],
                default="pending",
                max_length=16,
            ),
        ),
        migrations.AlterField(
            model_name="jobapplication",
            name="status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("reviewing", "Reviewing"),
                    ("shortlisted", "Shortlisted"),
                    ("interview", "Interview"),
                    ("offer", "Offer"),
                    ("hired", "Hired"),
                    ("declined", "Declined"),
                    ("withdrawn", "Withdrawn"),
                    ("job_taken", "Job taken"),
                ],
                default="pending",
                max_length=16,
            ),
        ),
        migrations.RunPython(migrate_accepted_applications, migrations.RunPython.noop),
    ]
